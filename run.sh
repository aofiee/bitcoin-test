#!/bin/bash

if [ ! -e ".env" ]; then
    echo "Please create .env file"
    exit 1
fi

source .env

if [ ! -e "docker-compose.yaml" ]; then
    echo "Please create docker-compose.yaml file"
    exit 1
else
    echo "Setup Chain"
    docker_compose_file="docker-compose.yaml"
    sed -i '' "s/-chain=[^ ]*/-chain=$CHAIN/" "$docker_compose_file"
fi

if [ ! -e "bitcoin-node-manager/src/Config.php" ]; then
    echo "Please create bitcoin-node-manager/src/Config.php file"
    exit 1
else
    echo "Setup environment variables"

    bitcoin_node_manager_path="bitcoin-node-manager/src/Config.php"

    sed -i '' "s/\(const RPC_IP = \).*/\1\"$RPCIP\";/" "$bitcoin_node_manager_path"
    sed -i '' "s/\(const RPC_PORT = \).*/\1\"$RPCPORT\";/" "$bitcoin_node_manager_path"
    sed -i '' "s/\(const RPC_USER = \).*/\1\"$RPCUSER\";/" "$bitcoin_node_manager_path"
    sed -i '' "s/\(const RPC_PASSWORD = \).*/\1\"$RPCPASSWORD\";/" "$bitcoin_node_manager_path"
fi


if [ ! -e "config/bfgminer.conf" ]; then
    echo "Please create config/bfgminer.conf file"
    exit 1
else
    echo "Setup environment variables"

    bfgminer_path="config/bfgminer.conf"

    sed -i '' "s|http://[^:]*:[0-9]*|http://$RPCIP:$RPCPORT|" "$bfgminer_path"
    sed -i '' "s|\"user\": \"[^\"]*\"|\"user\": \"$RPCUSER\"|" "$bfgminer_path"
    sed -i '' "s|\"pass\": \"[^\"]*\"|\"pass\": \"$RPCPASSWORD\"|" "$bfgminer_path"

fi

if [ ! -e "config/bitcoin.conf" ]; then
    echo "Please create config/bitcoin.conf file"
    exit 1
else
    echo "Setup environment variables"

    bitcoin_path="config/bitcoin.conf"

    sed -i '' "s/^rpcuser=.*/rpcuser=$RPCUSER/" "$bitcoin_path"
    sed -i '' "s/^rpcpassword=.*/rpcpassword=$RPCPASSWORD/" "$bitcoin_path"
fi



echo "Starting docker containers"

docker-compose up bitcoind -d

is_bitcoind_ready() {
    local container_name="bitcoind"
    local running=$(docker inspect -f "{{.State.Running}}" $container_name 2>/dev/null)
    if [ "$running" != "true" ]; then
        return 1
    fi

    if docker exec bitcoind bash -c "bitcoin-cli -chain=${CHAIN} -rpcuser=${RPCUSER} -rpcpassword=${RPCPASSWORD} -rpcport=${RPCPORT} getblockchaininfo"  &>/dev/null; then
        return 0
    else
        return 1
    fi
}

echo "Waiting for bitcoind to be ready..."
until is_bitcoind_ready; do
    echo "Waiting..."
    sleep 5
done

echo "bitcoind is ready. Proceeding to the next task."


docker exec bitcoind bash -c "bitcoin-cli -chain=${CHAIN} -rpcuser=${RPCUSER} -rpcpassword=${RPCPASSWORD} -rpcport=${RPCPORT} createwallet ${WALLET_NAME}"
WALLET_ADDRESS=$(docker exec bitcoind bash -c "bitcoin-cli -chain=${CHAIN} -rpcuser=${RPCUSER} -rpcpassword=${RPCPASSWORD} -rpcport=${RPCPORT} -rpcwallet=${WALLET_NAME} getnewaddress -addresstype legacy" 2>&1)


if [[ "$WALLET_ADDRESS" == *"Error"* ]]; then
    echo "error: failed to get wallet address."
    exit 1
else

    sed -i '' "s/\(WALLET_NAME=\).*/\1$WALLET_NAME/" ".env"
    sed -i '' "s/\(WALLET_ADDRESS=\).*/\1$WALLET_ADDRESS/" ".env"

    if [ ! -e "config/cgminer.conf" ]; then
        echo "Please create config/cgminer.conf file"
        exit 1
    else
        echo "Setup environment variables"

        cgminer_path="config/cgminer.conf"

        sed -i '' "s|http://[^:]*:[0-9]*|http://$RPCIP:$RPCPORT|" "$cgminer_path"
        sed -i '' "s|\"user\": \"[^\"]*\"|\"user\": \"$RPCUSER\"|" "$cgminer_path"
        sed -i '' "s|\"pass\": \"[^\"]*\"|\"pass\": \"$RPCPASSWORD\"|" "$cgminer_path"
        sed -i '' "s|\"btc-address\": \"[^\"]*\"|\"btc-address\": \"$WALLET_ADDRESS\"|" "$cgminer_path"
    fi

    if [ ! -e "docker-compose.yaml" ]; then
        echo "Please create docker-compose.yaml file"
        exit 1
    else
        echo "Setup environment variables"
        docker_compose_file="docker-compose.yaml"
        sed -i '' "s/--coinbase-addr=[^ ]*/--coinbase-addr=$WALLET_ADDRESS/" "$docker_compose_file"
        sed -i '' "s/--generate-to=[^ ]*/--generate-to=$WALLET_ADDRESS/" "$docker_compose_file"
        sed -i '' "s/-chain=[^ ]*/-chain=$CHAIN/" "$docker_compose_file"
    fi

    if [ ! -e "config/cpuminer.conf" ]; then
        echo "Please create config/cpuminer.conf file"
        exit 1
    else
        echo "Setup environment variables"

        cpuminer_path="config/cpuminer.conf"

        sed -i '' "s|http://[^:]*:[0-9]*|http://$RPCIP:$RPCPORT|" "$cpuminer_path"
        sed -i '' "s|\"user\": \"[^\"]*\"|\"user\": \"$RPCUSER\"|" "$cpuminer_path"
        sed -i '' "s|\"pass\": \"[^\"]*\"|\"pass\": \"$RPCPASSWORD\"|" "$cpuminer_path"
    fi
fi

echo "Wallet address: ${WALLET_ADDRESS}"
echo "Chain: ${CHAIN}"
source .env

if [ "$CHAIN" = "regtest" ]; then
    docker exec bitcoind bash -c "bitcoin-cli -chain=${CHAIN} -rpcuser=${RPCUSER} -rpcpassword=${RPCPASSWORD} -rpcport=${RPCPORT} generatetoaddress 250 ${WALLET_ADDRESS}"
    echo "generating 250 blocks"
fi

sleep 60s & 
pid=$!
wait $pid

echo "Starting cpuminer server"
docker-compose up bitcoin-node-manager -d
docker-compose up cpuminer -d
docker-compose logs --follow
