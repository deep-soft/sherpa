#!/usr/bin/env bash

# OneCD's async FIFO pipe reader proof-of-concept
# have multiple background procs all send data to a single named pipe.
# at the same time, read from this pipe, and update the state of specific QPKG arrays according to details in data.

mypipe=test.pipe
data=''
n=''

# need to create a few state arrays here, so there's something to modify and check later

[[ ! -p $mypipe ]] && mknod "$mypipe" p

receiver()
    {

    while true; do
        read data
        if [[ -z $data ]]; then
            sleep 1
            continue
        fi

        if [[ -n $data ]]; then
            # this is where QPKG state arrays should be updated using data from senders
            echo "this was just seen in the pipe: [$data]"
        fi
    done < "$mypipe"

    }

_sender_()
    {

    # * this function runs as a background process *

    # $1 = id
    # $2 = iterations - default is 5

    local count=${2:-5}

    for x in $(seq "$count"); do
        echo "${1:-}: ["$(date)"]" > $mypipe
        sleep 1
    done

    }

# redirect fd1 from function to fd5
exec 5< <(receiver)
echo 'after the redirect to fd5'

# launch background procs to write data to $mypipe
declare -i pid=0
declare -a pids=()

_sender_ ae35 &
pids+=($!)
_sender_ ae48 &
pids+=($!)
_sender_ ae56 3 &
pids+=($!)
_sender_ ae64 6 &
pids+=($!)

echo 'before wait'

for pid in ${pids[@]}; do
    wait $pid
done

echo 'after wait'

# reset current fd5 back to fd1. This will kill the instance of receiver()
exec 5>&-
echo 'after the redirection reset'

# now display contents of state arrays
