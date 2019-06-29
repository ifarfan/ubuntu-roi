#!/usr/bin/env bash
#
#  Flush cached memory
#
sync
echo 3 > /proc/sys/vm/drop_caches 2>&1
exit 0
