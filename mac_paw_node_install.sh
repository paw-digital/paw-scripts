#!/bin/sh

#check installs
command -v curl >/dev/null 2>&1 || { echo "Requires curl but it's not installed. Use brew install curl" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Requires jq but it's not installed. Use brew install jq" >&2; exit 1; }

#Install paw_node
curl -s -L https://github.com/paw-digital/paw-node/releases/download/v1/mac-paw_node > /usr/local/bin/paw_node
chmod +x /usr/local/bin/paw_node
echo "Paw Node installed /usr/local/bin/paw_node"

#Create data dir
datadir=~/"Library/Paw"
if [ ! -d $datadir ]
then
    echo "Creating data directory ${datadir}"
    mkdir $datadir
fi

#Generate config for node
config_node_file=$datadir"/config-node.toml"
ip=$(curl -s https://ipinfo.io/ip)
if [ ! -f $config_node_file ]
then
    echo "Creating node config" $config_node_file
    node_config=$(paw_node --generate_config node)
    node_config=$(echo "$node_config" | sed "s/\[rpc\]/[rpc]\n\nenable = true/g")
    node_config=$(echo "$node_config" | sed "s/\#enable_voting\ \=\ false/enable_voting = true/g")
    echo "$node_config" > $config_node_file
fi

#Generate config for rpc
rpc_node_file=$datadir"/config-rpc.toml"
if [ ! -f $rpc_node_file ]
then
    echo "Creating rpc config" $rpc_node_file
    rpc_config=$(paw_node --generate_config rpc)
    rpc_config=$(echo "$rpc_config" | sed "s/\#enable_control\ \=\ false/enable_control = true/g")
    echo "$rpc_config" > $rpc_node_file
fi

#Start daemon
paw_node --daemon --data_path=$datadir > /dev/null  2>&1 &
if [ $? -ne 0 ]
then
  echo "Could not start daemon"
  exit 1
fi
sleep 1

#Create rep account
wallet=$(curl -s -d '{"action": "wallet_create"}' http://localhost:7046 | jq -r '.wallet')
if [ "$wallet" = "null"  ] || [ -z "$wallet" ]
then
    echo "Failed to create wallet"
    exit 1
fi
account=$(curl -s -d "{\"action\": \"account_create\",\"wallet\": \"${wallet}\"}" http://localhost:7046  | jq -r '.account')
if [ "$account" = "null" ] || [ -z "$account" ]
then
    echo "Failed to create account"
    exit 1
fi
echo "Your tribe has been created ${account} please send at least 0.01 PAW to this account to open it. Your tribe will start voting once its open and has over 1000 PAW delegated."

#Disable enable control
rpc_config=$(paw_node --generate_config rpc)
echo "$rpc_config" > $rpc_node_file

#Restart daemon
killall -9 paw_node > /dev/null 2>&1
sleep 5
paw_node --daemon --data_path=$datadir > /dev/null  2>&1 &
if [ $? -ne 0 ]
then
  echo "Could not start daemon"
  exit 1
fi
echo "Node is running"
echo "Node address: ${ip}:7045"
echo "\n====\n"

private_key=$(paw_node --wallet_decrypt_unsafe --wallet=${wallet} | sed "s/\ P/\nP/g")
echo "Please store your private key safely and confidentially!"
echo "${private_key}"
