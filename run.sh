#!/bin/bash

if [ ! -e ".env" ]; then
    echo "Please create .env file"
    exit 1
fi

source .env

# Setup bitcore chain
if [ ! -e "dockerfile/bitcoind/docker-compose.yml" ]; then
    echo "Please create dockerfile/bitcoind/docker-compose.yml file"
    exit 1
else
    echo "Setup bitcore chain environment variables"
    docker_compose_file="dockerfile/bitcoind/docker-compose.yml"
    sed -i '' "s/-chain=[^ ]*/-chain=$BITCOIN_CHAIN/" "$docker_compose_file"
fi

# Setup stratumdb environment variables
if [ ! -e "dockerfile/stratumdb/docker-compose.yml" ]; then
    echo "Please create dockerfile/stratumdb/docker-compose.yml file"
    exit 1
else
    echo "Setup stratumdb environment variables"
    docker_compose_file="dockerfile/stratumdb/docker-compose.yml"
    sed -i '' "s/- MYSQL_USER=[^ ]*/- MYSQL_USER=${STRATUM_DB_USER}/" "$docker_compose_file"
    sed -i '' "s/- MYSQL_PASSWORD=[^ ]*/- MYSQL_PASSWORD=${STRATUM_DB_PASSWORD}/" "$docker_compose_file"
    sed -i '' "s/- MYSQL_DATABASE=[^ ]*/- MYSQL_DATABASE=${STRATUM_DB_NAME}/" "$docker_compose_file"
    sed -i '' "s/- MYSQL_ROOT_PASSWORD=[^ ]*/- MYSQL_ROOT_PASSWORD=${STRATUM_DB_PASSWORD}/" "$docker_compose_file"    
fi

if [ ! -e "config/stratum.py" ]; then
    echo "Please create config/stratum.py file"
    exit 1
else
    echo "Setup Stratum minning environment variables"
    stratum_config_file="config/stratum.py"
    sed -i '' "s/DATABASE_DRIVER = .*/DATABASE_DRIVER = '$STRATUM_DB'/" "$stratum_config_file"
    sed -i '' "s/DB_MYSQL_HOST = .*/DB_MYSQL_HOST = '$STRATUM_DB_HOST'/" "$stratum_config_file"
    sed -i '' "s/DB_MYSQL_DBNAME = .*/DB_MYSQL_DBNAME = '$STRATUM_DB_NAME'/" "$stratum_config_file"
    sed -i '' "s/DB_MYSQL_USER = .*/DB_MYSQL_USER = '$STRATUM_DB_USER'/" "$stratum_config_file"
    sed -i '' "s/DB_MYSQL_PASS = .*/DB_MYSQL_PASS = '$STRATUM_DB_PASSWORD'/" "$stratum_config_file"
    sed -i '' "s/COINDAEMON_TRUSTED_HOST = .*/COINDAEMON_TRUSTED_HOST = '$BITCOIN_RPCIP'/" "$stratum_config_file"
    sed -i '' "s/COINDAEMON_TRUSTED_PORT = .*/COINDAEMON_TRUSTED_PORT = $BITCOIN_RPCPORT/" "$stratum_config_file"
    sed -i '' "s/COINDAEMON_TRUSTED_USER = .*/COINDAEMON_TRUSTED_USER = '$BITCOIN_RPCUSER'/" "$stratum_config_file"
    sed -i '' "s/COINDAEMON_TRUSTED_PASSWORD = .*/COINDAEMON_TRUSTED_PASSWORD = '$BITCOIN_RPCPASSWORD'/" "$stratum_config_file"

fi

if [ ! -e "bitcoin-node-manager/src/Config.php" ]; then
    if [ ! -e "bitcoin-node-manager/src/Config.sample.php" ]; then
        echo "Please create bitcoin-node-manager/src/Config.php file"
        exit 1
    else
        echo "Setup Node Manager environment variables"
        cp bitcoin-node-manager/src/Config.sample.php bitcoin-node-manager/src/Config.php

        bitcoin_node_manager_path="bitcoin-node-manager/src/Config.php"

        sed -i '' "s/\(const RPC_IP = \).*/\1\"$BITCOIN_RPCIP\";/" "$bitcoin_node_manager_path"
        sed -i '' "s/\(const RPC_PORT = \).*/\1\"$BITCOIN_RPCPORT\";/" "$bitcoin_node_manager_path"
        sed -i '' "s/\(const RPC_USER = \).*/\1\"$BITCOIN_RPCUSER\";/" "$bitcoin_node_manager_path"
        sed -i '' "s/\(const RPC_PASSWORD = \).*/\1\"$BITCOIN_RPCPASSWORD\";/" "$bitcoin_node_manager_path"
        sed -i '' "s/\(const PASSWORD = \).*/\1\"$BITCOIN_NODEMANAGER_PASSWORD\";/" "$bitcoin_node_manager_path"
    fi
    
else
    echo "Setup Node Manager environment variables"

    bitcoin_node_manager_path="bitcoin-node-manager/src/Config.php"

    sed -i '' "s/\(const RPC_IP = \).*/\1\"$BITCOIN_RPCIP\";/" "$bitcoin_node_manager_path"
    sed -i '' "s/\(const RPC_PORT = \).*/\1\"$BITCOIN_RPCPORT\";/" "$bitcoin_node_manager_path"
    sed -i '' "s/\(const RPC_USER = \).*/\1\"$BITCOIN_RPCUSER\";/" "$bitcoin_node_manager_path"
    sed -i '' "s/\(const RPC_PASSWORD = \).*/\1\"$BITCOIN_RPCPASSWORD\";/" "$bitcoin_node_manager_path"
fi


if [ ! -e "config/bfgminer.conf" ]; then
    echo "Please create config/bfgminer.conf file"
    exit 1
else
    echo "Setup BFGMiner environment"

    bfgminer_path="config/bfgminer.conf"

    sed -i '' "s|http://[^:]*:[0-9]*|http://$BITCOIN_RPCIP:$BITCOIN_RPCPORT|" "$bfgminer_path"
    sed -i '' "s|\"user\": \"[^\"]*\"|\"user\": \"$BITCOIN_RPCUSER\"|" "$bfgminer_path"
    sed -i '' "s|\"pass\": \"[^\"]*\"|\"pass\": \"$BITCOIN_RPCPASSWORD\"|" "$bfgminer_path"

fi

if [ ! -e "config/bitcoin.conf" ]; then
    echo "Please create config/bitcoin.conf file"
    exit 1
else
    echo "Setup Bitcoin environment"

    bitcoin_path="config/bitcoin.conf"

    sed -i '' "s/^rpcuser=.*/rpcuser=$BITCOIN_RPCUSER/" "$bitcoin_path"
    sed -i '' "s/^rpcpassword=.*/rpcpassword=$BITCOIN_RPCPASSWORD/" "$bitcoin_path"
fi



echo "Starting docker containers"


is_bitcoind_ready() {
    local container_name="bitcoind"
    local running=$(docker inspect -f "{{.State.Running}}" $container_name 2>/dev/null)
    if [ "$running" != "true" ]; then
        return 1
    fi

    if docker exec bitcoind bash -c "bitcoin-cli -chain=${BITCOIN_CHAIN} -rpcuser=${BITCOIN_RPCUSER} -rpcpassword=${BITCOIN_RPCPASSWORD} -rpcport=${BITCOIN_RPCPORT} getblockchaininfo"  &>/dev/null; then
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

    if docker exec stratumdb bash -c "mysql -u${STRATUM_DB_USER} -p${STRATUM_DB_PASSWORD} -h${STRATUM_DB_HOST} -e 'show databases;'"  &>/dev/null; then
        return 0
    else
        return 1
    fi
}

if [ "$BITCOINCORE" == "true" ]; then
    echo "Starting bitcoind server"
    docker-compose up bitcoind -d
    echo "Waiting for bitcoind to be ready..."
    until is_bitcoind_ready; do
        echo "Waiting..."
        sleep 5
    done

    echo "bitcoind is ready. Proceeding to the next task."

    docker exec bitcoind bash -c "bitcoin-cli -chain=${BITCOIN_CHAIN} -rpcuser=${BITCOIN_RPCUSER} -rpcpassword=${BITCOIN_RPCPASSWORD} -rpcport=${BITCOIN_RPCPORT} createwallet ${BITCOIN_WALLETNAME}"
BITCOIN_WALLETADDRESS=$(docker exec bitcoind bash -c "bitcoin-cli -chain=${BITCOIN_CHAIN} -rpcuser=${BITCOIN_RPCUSER} -rpcpassword=${BITCOIN_RPCPASSWORD} -rpcport=${BITCOIN_RPCPORT} -rpcwallet=${BITCOIN_WALLETNAME} getnewaddress -addresstype legacy" 2>&1)

    if [[ "$BITCOIN_WALLETADDRESS" == *"Error"* ]]; then
        echo "error: failed to get wallet address."
        exit 1
    else

        sed -i '' "s/\(BITCOIN_WALLETNAME=\).*/\1$BITCOIN_WALLETNAME/" ".env"
        sed -i '' "s/\(BITCOIN_WALLETADDRESS=\).*/\1$BITCOIN_WALLETADDRESS/" ".env"

        if [ ! -e "config/cgminer.conf" ]; then
            echo "Please create config/cgminer.conf file"
            exit 1
        else
            echo "Setup CGMiner environment variables"

            cgminer_path="config/cgminer.conf"

            sed -i '' "s|http://[^:]*:[0-9]*|http://$BITCOIN_RPCIP:$BITCOIN_RPCPORT|" "$cgminer_path"
            sed -i '' "s|\"user\": \"[^\"]*\"|\"user\": \"$BITCOIN_RPCUSER\"|" "$cgminer_path"
            sed -i '' "s|\"pass\": \"[^\"]*\"|\"pass\": \"$BITCOIN_RPCPASSWORD\"|" "$cgminer_path"
            sed -i '' "s|\"btc-address\": \"[^\"]*\"|\"btc-address\": \"$BITCOIN_WALLETADDRESS\"|" "$cgminer_path"
        fi

        # Setup bfgminer wallet address
        if [ ! -e "dockerfile/bfgminer/docker-compose.yml" ]; then
            echo "Please create dockerfile/bfgminer/docker-compose.yml file"
            exit 1
        else
            echo "Setup bfgminer wallet address"
            docker_compose_file="dockerfile/bfgminer/docker-compose.yml"
            sed -i '' "s/--generate-to=[^ ]*/--generate-to=$BITCOIN_WALLETADDRESS/" "$docker_compose_file"
        fi

        # Setup cpuminer wallet address
        if [ ! -e "dockerfile/cpuminer/docker-compose.yml" ]; then
            echo "Please create dockerfile/cpuminer/docker-compose.yml file"
            exit 1
        else
            echo "Setup cpuminer wallet address"
            docker_compose_file="dockerfile/cpuminer/docker-compose.yml"
            sed -i '' "s/--coinbase-addr=[^ ]*/--coinbase-addr=$BITCOIN_WALLETADDRESS/" "$docker_compose_file"
        fi

        if [ ! -e "config/cpuminer.conf" ]; then
            echo "Please create config/cpuminer.conf file"
            exit 1
        else
            echo "Setup cpuminer environment variables"

            cpuminer_path="config/cpuminer.conf"

            sed -i '' "s|http://[^:]*:[0-9]*|http://$BITCOIN_RPCIP:$BITCOIN_RPCPORT|" "$cpuminer_path"
            sed -i '' "s|\"user\": \"[^\"]*\"|\"user\": \"$BITCOIN_RPCUSER\"|" "$cpuminer_path"
            sed -i '' "s|\"pass\": \"[^\"]*\"|\"pass\": \"$BITCOIN_RPCPASSWORD\"|" "$cpuminer_path"
        fi
    fi

    echo "Wallet address: ${BITCOIN_WALLETADDRESS}"
    echo "Chain: ${BITCOIN_CHAIN}"
    source .env

    if [ "$BITCOIN_CHAIN" = "regtest" ]; then
        docker exec bitcoind bash -c "bitcoin-cli -chain=${BITCOIN_CHAIN} -rpcuser=${BITCOIN_RPCUSER} -rpcpassword=${BITCOIN_RPCPASSWORD} -rpcport=${BITCOIN_RPCPORT} generatetoaddress 250 ${BITCOIN_WALLETADDRESS}"
        echo "generating 250 blocks"
    fi

    sleep 60s & 
    pid=$!
    wait $pid

fi


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

if [ "$STRATUM" = "true" ]; then
    echo "Starting stratum server"
    docker-compose up stratumdb -d
    echo "Waiting for stratumdb to be ready..."
    until is_stratumdb_ready; do
        echo "Waiting..."
        sleep 5
    done
    docker-compose up stratum -d
fi

docker-compose logs --follow