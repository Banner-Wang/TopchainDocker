#!/bin/bash

# Redirect all output (stdout and stderr) to /tmp/check.log
exec >> /tmp/startup_check.log 2>&1

# Function to output logs with timestamp
log_with_timestamp() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Check if xnode process is running
process_count=$(ps -ef | grep xnode | grep -v grep | wc -l)

# Debugging output
log_with_timestamp "Process count: $process_count"

if [[ $process_count -eq 1 ]]; then
    # Check if node is joined
    is_joined=$(/chain/topio node isjoined | head -n1)
    
    # Debugging output
    log_with_timestamp "Is joined: $is_joined"
    
    if [[ "$is_joined" == "YES" ]]; then
        log_with_timestamp "---> Startup check successfully!"
        exit 0
    else
        log_with_timestamp "---> Node is not joined!"
        exit 1
    fi
else
    log_with_timestamp "---> xnode process is not running!"
    exit 1
fi

