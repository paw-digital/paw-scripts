#!/bin/sh

#check installs
command -v curl >/dev/null 2>&1 || { echo "Requires curl but it's not installed. If Ubuntu use apt-get install wget" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Requires jq but it's not installed. If Ubuntu use apt-get install jq" >&2; exit 1; }

#Install paw_node
curl -s -L https://github.com/paw-digital/paw-node/releases/latest/download/paw_node > /usr/local/bin/paw_node
chmod +x /usr/local/bin/paw_node
echo "Paw Node installed /usr/local/bin/paw_node"

#Create data dir
if [ ! -d ~/Paw ]
then
    echo "Creating data directory" ~/Paw
    mkdir ~/Paw
fi

#Generate config for node
config_node_file=~/Paw"/config-node.toml"
if [ ! -f $config_node_file ]
then
    echo "Creating node config" $config_node_file
    ip=$(curl -s https://ipinfo.io/ip)
    node_config=$(paw_node --generate_config node)
    node_config=$(echo "$node_config" | sed "s/\[rpc\]/[rpc]\n\nenable = true/g")
    node_config=$(echo "$node_config" | sed "s/\#external_port\ \= 0/external_port = 7045/g")
    node_config=$(echo "$node_config" | sed "s/\#external_port\ \= 0/external_port = 7045/g")
    node_config=$(echo "$node_config" | sed "s/\#enable_voting\ \=\ false/enable_voting = true/g")
    echo "$node_config" > $config_node_file
fi

#Generate config for rpc
rpc_node_file=~/Paw"/config-rpc.toml"
if [ ! -f $rpc_node_file ]
then
    echo "Creating rpc config" $rpc_node_file
    rpc_config=$(paw_node --generate_config rpc)
    rpc_config=$(echo "$rpc_config" | sed "s/\#enable_control\ \=\ false/enable_control = true/g")
    echo "$rpc_config" > $rpc_node_file
fi

#Start daemon
paw_node --daemon > /dev/null &
sleep 1

#Create rep account
wallet=$(curl -s -d '{"action": "wallet_create"}' http://[::1]:7046 | jq -r '.wallet')
account=$(curl -s -d "{\"action\": \"account_create\",\"wallet\": \"${wallet}\"}" http://[::1]:7046  | jq -r '.account')
echo "Your tribe has been created ${account} please send at least 0.01 PAW to this account to open it. Your tribe will start voting once its open and has over 1000 PAW delegated."

#Disable enable control
rpc_config=$(paw_node --generate_config rpc)
echo "$rpc_config" > $rpc_node_file

#Restart daemon
killall -9 paw_node
sleep 5
paw_node --daemon > /dev/null &
echo "Node is running"