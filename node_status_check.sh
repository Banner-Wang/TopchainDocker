#!/bin/bash

log() {
  # This function is from espnet
  local fname=${BASH_SOURCE[1]##*/}
  echo -e "$(date '+%Y-%m-%d %H:%M:%S') (${fname}:${BASH_LINENO[0]}:${FUNCNAME[1]}) $*"
}


# Function to notify via DingTalk
notify_dingding() {
    local dingding_robot_token=$1
    local title=$2
    local msg=$3
    
    if [ -z "$dingding_robot_token" ]; then
        log "Dingding robot token not found"
        exit 1
    fi
    
    webhook="https://oapi.dingtalk.com/robot/send?access_token=${dingding_robot_token}"
    
    curl -H "Content-Type: application/json" -d "{\"msgtype\": \"markdown\",\"markdown\": {\"title\":\"$title\",\"text\":\"$msg\"}}" "$webhook"
}

# Function to check topio status
check_topio_status() {
    if ! ps -ef | grep topio | grep -v grep | grep -q "topio: xnode process" || ! ps -ef | grep topio | grep -v grep | grep -q "topio: daemon process"; then
        log "ERROR: topio program abnormal: xnode process or daemon process missing"
        exit 1
    else
        log "INFO: topio program running normally"
    fi
}

# Function to check topio network status
check_topio_network_status() {
    output=$(/chain/topio node isjoined)
    if [ "$output" = "YES" ]; then
        log "INFO: node is joined"
    else
        log "WARNING: node is not joined"
    fi
}

# Function to check sync status
check_sync_status() {
    local account=$1
    output=$(/chain/topio chain syncstatus)
    
    # Parse output to get total values for each sync-mode
    declare -A sync_status
    while IFS=',' read -r mode total; do
        if [[ $total =~ total:[[:space:]]([0-9.]+)% ]]; then
            sync_status[$mode]=${BASH_REMATCH[1]}
        fi
    done <<< "$output"
    
    # Check if all modes have total value of 100
    all_synced=true
    for value in "${sync_status[@]}"; do
        if (( $(echo "$value != 100" | bc -l) )); then
            all_synced=false
            break
        fi
    done
    
    if $all_synced; then
        log "INFO: All nodes have completed synchronization"
    else
        title="Node synchronization status lagging alert"
        message="**Node address:** $account
**Sync status:** ${sync_status[@]}"
        log "WARNING: $title"
        log "$message"
        notify_dingding "$DINGDING_ROBOT_TOKEN" "$title" "$message"
    fi
}

# Function to check core files
check_core_files() {
    local account=$1
    core_files=$(ls -l /chain | grep core)
    
    if [ -z "$core_files" ]; then
        log "INFO: No core files"
    else
        core_count=$(echo "$core_files" | wc -l)
        
        if [ "$core_count" -eq 1 ]; then
            newest_date=$(echo "$core_files" | awk '{print $6, $7, $8}')
            log "WARNING: There is 1 core file, core file date: $newest_date"
            title="Node core file alert"
            message="**Node address:** $account
**Core file info:** There is 1 core file, core file date: $newest_date"
        else
            oldest_date=$(echo "$core_files" | head -n 1 | awk '{print $6, $7, $8}')
            newest_date=$(echo "$core_files" | tail -n 1 | awk '{print $6, $7, $8}')
            log "WARNING: There are $core_count core files, oldest core file date: $oldest_date, newest core file date: $newest_date"
            title="Node core file alert"
            message="**Node address:** $account
**Core file info:** There are $core_count core files, oldest core file date: $oldest_date, newest core file date: $newest_date"
        fi
        
        notify_dingding "$DINGDING_ROBOT_TOKEN" "$title" "$message"
    fi
}

# Function to check error logs
check_error_logs() {
    local account=$1
    log_files=$(ls /chain/log/xtop*log 2>/dev/null)
    
    if [ -z "$log_files" ]; then
        log "WARNING: No matching log files found"
        return
    fi
    
    error_logs=$(grep -a Error $log_files)
    
    if [ -z "$error_logs" ]; then
        log "INFO: No Error logs"
    else
        log "WARNING: Error logs as follows: $error_logs"
        title="Node Error log alert"
        message="**Node address:** $account
**Error log info:** $error_logs"
        log "WARNING: $title"
        log "$message"
        notify_dingding "$DINGDING_ROBOT_TOKEN" "$title" "$message"
    fi
}

# Function to get account address
get_account_addr() {
    if [ -f "/chain/keystore/config.json" ]; then
        jq -r '."account address"' /chain/keystore/config.json
    else
        log "ERROR: config.json file not found"
        exit 1
    fi
}

# Main function
main() {
    account=$(get_account_addr)
    
    # Execute task A
    check_topio_status
    
    # Get current time
    current_hour=$(date +%H)
    current_minute=$(date +%M)
    current_second=$(date +%S)
    
    # Check if task B should be executed (once every hour)
    # Trigger in the first 5 seconds of the first minute of every hour
    trigger_seconds=${TRIGGER_SECONDS:-5}  # Default to 5 seconds if TRIGGER_SECONDS is not set
    if [ "$current_minute" -eq 0 ] && [ "$current_second" -lt "$trigger_seconds" ]; then
        check_sync_status "$account"
        check_core_files "$account"
        check_error_logs "$account"
    fi   
}

# Run main function
main