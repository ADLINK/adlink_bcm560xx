#!/bin/bash
####################################################################
# File:
#     bcm.sh
# Description:
#     Launch/terminate Broadcom diagnostic shell.
# Usage:
#     ./bcm.sh {start|stop|restart}
####################################################################

MY_DIR=`cd $(dirname $0);pwd`
LISTENER_PORT=9895
CONFIG_FILE=${MY_DIR}/config.bcm
FLAG_FILE=${MY_DIR}/start
NETSERVE=${MY_DIR}/netserve
LOG_FILE=${MY_DIR}/bcm.log
EXEC=${MY_DIR}/bcm.user

start_bcm_user() {
    rm -f ${FLAG_FILE}

    lsmod | grep -q "^linux_kernel_bde"
    if [ $? -ne 0 ]; then
        # forceirq=113
        # usemsi=1,2
        insmod ${MY_DIR}/linux-kernel-bde.ko maxpayload=128 debug=4
        if [ $? -ne 0 ]; then
            echo "Failed to load module linux-kernel-bde.ko."
            exit 1
        fi
    fi
    
    lsmod | grep -q "^linux_user_bde"
    if [ $? -ne 0 ]; then
        insmod ${MY_DIR}/linux-user-bde.ko debug=4
        if [ $? -ne 0 ]; then
            echo "Failed to load module linux-user-bde.ko."
            exit 1
        fi
    fi
    
    if [ ! -e /dev/linux-user-bde ]; then
        dnum=`cat /proc/devices | grep linux-user-bde | awk '{print $1}'`
        mknod /dev/linux-user-bde c ${dnum} 0
        if [ $? -ne 0 ]; then
            echo "Failed to make user node."
            exit 1
        fi
    fi

    if [ ! -e /dev/linux-kernel-bde ]; then
        dnum=`cat /proc/devices | grep linux-kernel-bde | awk '{print $1}'`
        mknod /dev/linux-kernel-bde c ${dnum} 0
        if [ $? -ne 0 ]; then
            echo "Failed to make kernel node."
            exit 1
        fi
    fi

    export BCM_CONFIG_FILE=${CONFIG_FILE}
    cd ${MY_DIR}
    ${NETSERVE} -d ${LISTENER_PORT} ${EXEC} > ${LOG_FILE} 2>&1

    i=0;
    while true; do
        i=`expr  $i + 1`;
        [ $i -eq 80 ] && echo "Timeout!!" && exit 1 ; 
        sleep 1
        [ -f ${FLAG_FILE} ] && break;
        echo -n ".";
    done
}

stop_bcm_user() {
    killall ${NETSERVE}
    killall ${EXEC}
    rm -f ${FLAG_FILE}
    sleep 2
}

case "$1" in
    start)
        echo -n "Starting Broadcom Switch Software ."
        pidof ${EXEC} > /dev/null
        if [ $? -eq 0 ]; then
            echo "${EXEC} is already running!!"
            exit 1
        fi
        start_bcm_user
        echo "OK"
        ;;
    stop)
        echo -n "Stoping Broadcom Switch Software ."
        pidof ${EXEC} > /dev/null
        if [ $? -ne 0 ]; then
            echo "${EXEC} is not running!!"
            exit 1
        fi
        stop_bcm_user
        echo "OK"
        ;;
    restart)
        echo -n "Restarting BroadcomSwitch Software ."
        stop_bcm_user
        start_bcm_user
        echo "OK"
        ;;
    *)
        echo "Usage: ./$0 {start|stop|restart}"
        exit 1
        ;;
esac

exit 0
