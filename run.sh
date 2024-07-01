#!/bin/bash

echo "---> Set miner key..."

minerkey=$(cat /chain/minerkey)


echo "---> Starting safebox..."

source /etc/profile
while ! /chain/topio node safebox || ! /chain/topio mining setMinerKey $minerkey -f /chain/keystore_pwd.txt; do
    sleep 5
done

sleep 3

echo "---> Starting node..."
/chain/topio node startNode
sleep 3

echo "---> Starting topargus-agent"
/script/topargus-agent -f /chain/log/xmetric.log -a 142.93.126.168:9010 -d mainnet_73b1bd8 --split --nodaemon
