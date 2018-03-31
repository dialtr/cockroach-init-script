#!/bin/bash

### BEGIN INIT INFO
# Provides:           cockroachdb
# Required-Start:     $network $named $local_fs $remote_fs $time
# Required-Stop:      $network $named $local_fs $remote_fs $time
# Default-Start:      3 4 5
# Default-Stop:       0 1 2 6
# Short-Description:  Cockroach Database Server
# Description:        Cockroach Database Server
### END INIT INFO


# TODO(tdial): Cockroach already reads some of these values from environment
# variables, and in fact are named similarly. Until I can determine the
# official names of the options that I use, I'll define my own and pass them
# on the command line. I've prefixed them with X_ in order to avoid name
# collisions with the official names for now.

# Modify this to specify the bath to the cockroach binary.
X_COCKROACH_EXE="/opt/cockroach/cockroach"

# Modify this to be the IP address upon which to bind.
X_COCKROACH_HOST="192.168.0.105"

# Modify to specify data directory; this is a naive configuration that uses one.
X_COCKROACH_DATA="/data/cockroach"

# Modify to specify a log directory
X_COCKROACH_LOG_DIR="/var/log/cockroach"

# Modify to specify the location for the PID file
X_COCKROACH_PID="/var/lock/cockroach.lock"


# Definitions of exit status as defined by the Linux Standard Base
EXIT_STATUS_OK=0
EXIT_STATUS_DEAD_PID=1
EXIT_STATUS_STOPPED=3
EXIT_STATUS_UNKNOWN=4


do_start() {
  # Check to see if the PID file already exists.
  PID=`cat ${X_COCKROACH_PID} 2>/dev/null`
  if [ ! -z "${PID}" ]; then
    # It does, but perhaps it's stale. We'll check by using ps to see if the
    # process exists, and if so, whether it's running the cockroach binary.
    # If so, that is a fair indication that the server is already running.
    RUNNING=`ps -fp ${PID} | grep ${X_COCKROACH_EXE} | wc -l`
    if [ ${RUNNING} -eq 1 ]; then
      echo "CockroachDB is already running"
    fi
  fi

  # Start cockroach
  ${X_COCKROACH_EXE}                            \
    start                                       \
    --store=${X_COCKROACH_DATA}                 \
    --log-dir=${X_COCKROACH_LOG_DIR}            \
    --pid-file=${X_COCKROACH_PID}               \
    --insecure                                  \
    --background                                \
    --no-color                                  \
    1> ${X_COCKROACH_LOG_DIR}/cockroach.stdout  \
    2> ${X_COCKROACH_LOG_DIR}/cockroach.stderr

  # Check exit status.
  STATUS="$?"
  if [ ${STATUS} -ne 0 ]; then
    echo "CockroachDB failed to start - check ${X_COCKROACH_LOG_DIR}"
    exit "${EXIT_STATUS_UNKNOWN}"
  fi

  echo "CockroachDB started"
}


do_stop() {
  # Check to see if the PID file already exists.
  PID=`cat ${X_COCKROACH_PID} 2>/dev/null`
  if [ -z "${PID}" ]; then
    echo "CockroachDB is already stopped"
    exit 1
  fi
 
  ${X_COCKROACH_EXE}                            \
    quit                                        \
    --insecure                                  \
    > /dev/null 2>&1                            \

  # Check exit status.
  STATUS="$?"
  if [ ${STATUS} -ne 0 ]; then
    echo "CockroachDB failed to stop - check ${X_COCKROACH_LOG_DIR}"
    # Program or service status is unknown.
    exit "${EXIT_STATUS_UNKNOWN}"
  fi

  # Remove lock file, which cockroach apparently does not clean up.
  rm -f ${X_COCKROACH_PID}

  echo "CockroachDB stopped"
}


do_status() {
  # Check to see if the PID file already exists.
  PID=`cat ${X_COCKROACH_PID} 2>/dev/null`
  if [ ! -z "${PID}" ]; then
    # It does, but perhaps it's stale. We'll check by using ps to see if the
    # process exists, and if so, whether it's running the cockroach binary.
    # If so, that is a fair indication that the server is already running.
    RUNNING=`ps -fp ${PID} | grep ${X_COCKROACH_EXE} | wc -l`
    if [ ${RUNNING} -eq 1 ]; then
      echo "* CockroachDB running"
    else
      echo "* CockroachDB is stopped but PID file exists"
      exit "${EXIT_STATUS_DEAD_PID}"
    fi
  else
    echo "* CockroachDB stopped"
    # Program is stopped
    exit "${EXIT_STATUS_STOPPED}"
  fi
}


case "$1" in
  start)
    do_start
    ;;
  stop)
    do_stop
    ;;
  restart|force-reload)
    do_stop
    do_start
    ;;
  status)
    do_status
    ;;
  *)
    echo "Usage: cockroach.sh start|stop|restart|status"
    ;;
esac

exit "${EXIT_STATUS_OK}"
