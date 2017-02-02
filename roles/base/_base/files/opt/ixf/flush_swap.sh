#!/bin/bash
#===============================================================================
#
#  F L U S H _ S W A P . S H
#
#  Shamelessly stolen from:
#  http://askubuntu.com/questions/1357/how-to-empty-swap-if-there-is-free-ram
#
#===============================================================================

#  Flush cache memory, first
sync
echo 3 > /proc/sys/vm/drop_caches

#  Determine if there's enough free memory
free_data="$(free)"
mem_data="$(echo "$free_data" | grep 'Mem:')"
free_mem="$(echo "$mem_data" | awk '{print $4}')"
buffers="$(echo "$mem_data" | awk '{print $6}')"
cache="$(echo "$mem_data" | awk '{print $7}')"
total_free=$((free_mem + buffers + cache))
used_swap="$(echo "$free_data" | grep 'Swap:' | awk '{print $3}')"

#  Go for it!
echo -e "Free memory:\t$total_free kB ($((total_free / 1024)) MB)\nUsed swap:\t$used_swap kB ($((used_swap / 1024)) MB)"
if [[ $used_swap -eq 0 ]]; then
    echo "Congratulations! No swap is in use."
elif [[ $used_swap -lt $total_free ]]; then
    echo "Freeing swap..."
    sudo swapoff -a
    sudo swapon -a
else
    echo "Not enough free memory. Exiting."
    exit 1
fi
