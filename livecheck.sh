#!/bin/bash

daemon_process_count=$(ps -ef | grep 'topio' | grep 'daemon' | grep -v grep | wc -l)
xnode_process_count=$(ps -ef | grep 'topio' | grep 'xnode' | grep -v grep | wc -l)

if [ "$daemon_process_count" -ge 1 ] && [ "$xnode_process_count" -ge 1 ]; then
    exit 0
else
    exit 1
fi

