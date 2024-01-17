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
    sed -i '' "s/- MYSQL_USER=[^ ]*/- MYSQL_USER=${DBUSER}/" "$docker_compose_file"
    sed -i '' "s/- MYSQL_PASSWORD=[^ ]*/- MYSQL_PASSWORD=${DBPASSWORD}/" "$docker_compose_file"
    sed -i '' "s/- MYSQL_DATABASE=[^ ]*/- MYSQL_DATABASE=${DBNAME}/" "$docker_compose_file"
    sed -i '' "s/- MYSQL_ROOT_PASSWORD=[^ ]*/- MYSQL_ROOT_PASSWORD=${DBPASSWORD}/" "$docker_compose_file"
fi

if [ ! -e "config/stratum.py" ]; then
    echo "Please create config/stratum.py file"
    exit 1
else
    echo "Setup Stratum minning environment variables"
    stratum_config_file="config/stratum.py"
    sed -i '' "s/DATABASE_DRIVER = .*/DATABASE_DRIVER = '$DB'/" "$stratum_config_file"
    sed -i '' "s/DB_MYSQL_HOST = .*/DB_MYSQL_HOST = '$DBHOST'/" "$stratum_config_file"
    sed -i '' "s/DB_MYSQL_DBNAME = .*/DB_MYSQL_DBNAME = '$DBNAME'/" "$stratum_config_file"
    sed -i '' "s/DB_MYSQL_USER = .*/DB_MYSQL_USER = '$DBUSER'/" "$stratum_config_file"
    sed -i '' "s/DB_MYSQL_PASS = .*/DB_MYSQL_PASS = '$DBPASSWORD'/" "$stratum_config_file"

fi

if [ ! -e "bitcoin-node-manager/src/Config.php" ]; then
    if [ ! -e "bitcoin-node-manager/src/Config.sample.php" ]; then
        echo "Please create bitcoin-node-manager/src/Config.php file"
        exit 1
    else
        echo "Setup Node Manager environment variables"
        cp bitcoin-node-manager/src/Config.sample.php bitcoin-node-manager/src/Config.php

        bitcoin_node_manager_path="bitcoin-node-manager/src/Config.php"

        sed -i '' "s/\(const RPC_IP = \).*/\1\"$RPCIP\";/" "$bitcoin_node_manager_path"
        sed -i '' "s/\(const RPC_PORT = \).*/\1\"$RPCPORT\";/" "$bitcoin_node_manager_path"
        sed -i '' "s/\(const RPC_USER = \).*/\1\"$RPCUSER\";/" "$bitcoin_node_manager_path"
        sed -i '' "s/\(const RPC_PASSWORD = \).*/\1\"$RPCPASSWORD\";/" "$bitcoin_node_manager_path"
        sed -i '' "s/\(const PASSWORD = \).*/\1\"$NODEMANAGERPASSWORD\";/" "$bitcoin_node_manager_path"
    fi
    
else
    echo "Setup Node Manager environment variables"

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
    echo "Setup BFGMiner environment"

    bfgminer_path="config/bfgminer.conf"

    sed -i '' "s|http://[^:]*:[0-9]*|http://$RPCIP:$RPCPORT|" "$bfgminer_path"
    sed -i '' "s|\"user\": \"[^\"]*\"|\"user\": \"$RPCUSER\"|" "$bfgminer_path"
    sed -i '' "s|\"pass\": \"[^\"]*\"|\"pass\": \"$RPCPASSWORD\"|" "$bfgminer_path"

fi

if [ ! -e "config/bitcoin.conf" ]; then
    echo "Please create config/bitcoin.conf file"
    exit 1
else
    echo "Setup Bitcoin environment"

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

is_stratumdb_ready() {
    local container_name="stratumdb"
    local running=$(docker inspect -f "{{.State.Running}}" $container_name 2>/dev/null)
    if [ "$running" != "true" ]; then
        return 1
    fi

    if docker exec stratumdb bash -c "mysql -u${DBUSER} -p${DBPASSWORD} -h${DBHOST} -e 'show databases;'"  &>/dev/null; then
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


docker exec bitcoind bash -c "bitcoin-cli -chain=${CHAIN} -rpcuser=${RPCUSER} -rpcpassword=${RPCPASSWORD} -rpcport=${RPCPORT} createwallet ${WALLETNAME}"
WALLETADDRESS=$(docker exec bitcoind bash -c "bitcoin-cli -chain=${CHAIN} -rpcuser=${RPCUSER} -rpcpassword=${RPCPASSWORD} -rpcport=${RPCPORT} -rpcwallet=${WALLETNAME} getnewaddress -addresstype legacy" 2>&1)


if [[ "$WALLETADDRESS" == *"Error"* ]]; then
    echo "error: failed to get wallet address."
    exit 1
else

    sed -i '' "s/\(WALLETNAME=\).*/\1$WALLETNAME/" ".env"
    sed -i '' "s/\(WALLETADDRESS=\).*/\1$WALLETADDRESS/" ".env"

    if [ ! -e "config/cgminer.conf" ]; then
        echo "Please create config/cgminer.conf file"
        exit 1
    else
        echo "Setup CGMiner environment variables"

        cgminer_path="config/cgminer.conf"

        sed -i '' "s|http://[^:]*:[0-9]*|http://$RPCIP:$RPCPORT|" "$cgminer_path"
        sed -i '' "s|\"user\": \"[^\"]*\"|\"user\": \"$RPCUSER\"|" "$cgminer_path"
        sed -i '' "s|\"pass\": \"[^\"]*\"|\"pass\": \"$RPCPASSWORD\"|" "$cgminer_path"
        sed -i '' "s|\"btc-address\": \"[^\"]*\"|\"btc-address\": \"$WALLETADDRESS\"|" "$cgminer_path"
    fi

    if [ ! -e "docker-compose.yaml" ]; then
        echo "Please create docker-compose.yaml file"
        exit 1
    else
        echo "Setup Wallet address and chain"
        docker_compose_file="docker-compose.yaml"
        sed -i '' "s/--coinbase-addr=[^ ]*/--coinbase-addr=$WALLETADDRESS/" "$docker_compose_file"
        sed -i '' "s/--generate-to=[^ ]*/--generate-to=$WALLETADDRESS/" "$docker_compose_file"
        sed -i '' "s/-chain=[^ ]*/-chain=$CHAIN/" "$docker_compose_file"
    fi

    if [ ! -e "config/cpuminer.conf" ]; then
        echo "Please create config/cpuminer.conf file"
        exit 1
    else
        echo "Setup CPUMiner environment variables"

        cpuminer_path="config/cpuminer.conf"

        sed -i '' "s|http://[^:]*:[0-9]*|http://$RPCIP:$RPCPORT|" "$cpuminer_path"
        sed -i '' "s|\"user\": \"[^\"]*\"|\"user\": \"$RPCUSER\"|" "$cpuminer_path"
        sed -i '' "s|\"pass\": \"[^\"]*\"|\"pass\": \"$RPCPASSWORD\"|" "$cpuminer_path"
    fi
fi

echo "Wallet address: ${WALLETADDRESS}"
echo "Chain: ${CHAIN}"
source .env

if [ "$CHAIN" = "regtest" ]; then
    docker exec bitcoind bash -c "bitcoin-cli -chain=${CHAIN} -rpcuser=${RPCUSER} -rpcpassword=${RPCPASSWORD} -rpcport=${RPCPORT} generatetoaddress 250 ${WALLETADDRESS}"
    echo "generating 250 blocks"
fi

sleep 60s & 
pid=$!
wait $pid

if [ "$CPUMINER" = "true" ]; then
    echo "Starting cpuminer server"
    docker-compose up cpuminer -d
fi

if [ "$CGMINER" = "true" ]; then
    echo "Starting cgminer server"
    docker-compose up cgminer -d
fi

if [ "$BFGMINER" = "true" ]; then
    echo "Starting bfgminer server"
    docker-compose up bfgminer -d
fi

if [ "$NODEMNG" = "true" ]; then
    echo "Starting bitcoin node manager server"
    docker-compose up bitcoin-node-manager -d
fi

docker-compose up stratumdb -d
echo "Waiting for stratumdb to be ready..."
until is_stratumdb_ready; do
    echo "Waiting..."
    sleep 5
done
docker-compose up stratum -d
docker-compose logs --follow