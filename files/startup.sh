#!/bin/bash
### startup.sh -- is called on boot on the head node,
#              -- which starts the whole application
# 
#

# some common files
LDIR="/leconte"
SHDIR="$LDIR/shared"
HOST_FILE="$SHDIR/hostfile"
LOGFILE="/tmp/fractalexplorer.log"


# list all hosts that the program will run on
hosts=($(cat $HOST_FILE | awk '{printf $1" "}'))

# common arguments to notify-send (image and title)
NSARGS="-i face-monkey fractalexplorer"

# arguments to fractalexplorer
FEARGS="-i1000 -k72 -crandom -F -L -P $SHDIR/share/fractalexplorer/default.frpath -ecuda -v5"

# Sometimes, we must run the notification daemon
#/usr/lib/notification-daemon/notification-daemon -r &
#notif_daemon_pid=$!

# this will hide the cursor on the screen. Normally, SDL
# handles this, but if not, uncomment these lines, and
# one at the end of the fill which kills the background
# process
#unclutter -idle .01 -root &
#unclutter_pid=$!

# print out info
echo num hosts: ${#hosts[@]} hosts: ${hosts[*]}


# our loop variable
keep_going=1


# loop until all hosts respond
while test $keep_going -ne 0 ; do
    keep_going=0
    for i in ${hosts[*]}; do
            # this command will timeout after 1 sec
            #, and only do 1 ping, so it should be a
            # quick way to tell if something is connected
            # this is returning 124, which means that ping
            # is timing out
            if timeout 2 ping -c 1 $i &> /dev/null; then
            echo "host $i is online"
        else
            echo "host $i not responding: $?"
            # notify send has
            notify-send $NSARGS -t 1500 "waiting on host $i"
            keep_going=1
        fi
    done
    # wait a little while, so we don't spam
    if test $keep_going -ne 0 ; then
        sleep 1
    fi
done

echo ""
echo "all hosts connected"
echo ""

# 
#notify-send $NSARGS "all hosts connected"

# start notification daemon, which we often don't need
#/usr/lib/notification-daemon/notification-daemon &


# reset loop variable
keep_going=1


# wait for them to set clocks. This tests whether MPI can run
while test $keep_going -ne 0 ; do
    $LDIR/runoncluster -N 1 sudo $LDIR/jetson_clocks.sh --restore $LDIR/jetson_settings/clock-gpu-max
    keep_going=$?
    if test $keep_going -ne 0 ; then
        sleep 1
    fi
done

# sleep, and wait for clock to take effect
sleep 3

sudo xboxdrv --silent &
xboxdrv_pid=$!

# reset loop variable
keep_going=1

while test $keep_going -ne 0 ; do
    notify-send $NSARGS -t 2500 "starting program"
    
    inner_keep_going=1
    while test $inner_keep_going -ne 0 ; do
        # try to set max clock
        $LDIR/runoncluster -N 1 sudo $LDIR/jetson_clocks.sh --restore $LDIR/jetson_settings/clock-gpu-max
        inner_keep_going=$?
        if test $inner_keep_going -ne 0 ; then
            sleep 2
        fi
    done

    #sleep 1
    echo "---------------------------" >> $LOGFILE
    echo "starting..." >> $LOGFILE
    echo "---------------------------" >> $LOGFILE

    # actually run the program
    $LDIR/runoncluster $SHDIR/bin/fractalexplorer $FEARGS >> $LOGFILE 2>&1
    keep_going=$?
    if test $keep_going -ne 0 ; then
        sleep 2
    fi
done

# notify that we are ending
notify-send $NSARGS -t 2500 "shutting down"
echo "done running fractalexplorer"

kill -9 $xboxdrv_pid



