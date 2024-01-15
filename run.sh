#!/bin/bash

spin_wheel() {
    local -a marks=('/' '-' '\' '|')
    local pid=$1
    local delay=0.1
    local spin_count=0

    echo -n "Processing: "

    # Keep spinning the wheel as long as the background process is running
    while kill -0 "$pid" 2>/dev/null; do
        echo -ne "${marks[spin_count % 4]}"

        # Move the cursor one character back (to overwrite the spinner)
        echo -ne "\b"

        # Increment the spin count and sleep for a short duration
        ((spin_count++))
        sleep "$delay"
    done

    # Print a new line once the process completes
    echo ""
}

if [ ! -e ".env" ]; then
    echo "Please create .env file"
    exit 1
fi

source .env

echo "Starting docker containers"

docker-compose up bitcoind -d
sleep 60s & 
pid=$!
spin_wheel "$pid"

docker exec bitcoind bash -c "bitcoin-cli -chain=${CHAIN} -rpcuser=${RPCUSER} -rpcpassword=${RPCPASSWORD} -rpcport=${RPCPORT} createwallet ${WALLET_NAME}"
WALLET_ADDRESS=$(docker exec bitcoind bash -c "bitcoin-cli -chain=${CHAIN} -rpcuser=${RPCUSER} -rpcpassword=${RPCPASSWORD} -rpcport=${RPCPORT} -rpcwallet=${WALLET_NAME} getnewaddress -addresstype legacy" 2>&1)

if [[ "$WALLET_ADDRESS" == *"Error"* ]]; then
    echo "error: failed to get wallet address."
    exit 1
else
    sed -i '/WALLET_NAME/d' ".env"
    sed -i '/WALLET_ADDRESS/d' ".env"

    for key in "WALLET_NAME" "WALLET_ADDRESS"; do
        value="${!key}"
        # check if the key already exists in the .env file
        if grep -q "^$key=" .env; then
            # update the existing key with the new value
            if sed --version 2>&1 | grep -q "GNU"; then
                sed -i 's/^'"$key"'=.*/'"$key=$value"'/' .env
            else
                sed -i "" 's/^'"$key"'=.*/'"$key=$value"'/' .env
            fi
        else
            # append the new key-value pair to the .env file
            echo "$key=$value" >> .env
        fi
    done
fi

echo "Wallet address: ${WALLET_ADDRESS}"
echo "Chain: ${CHAIN}"
source .env

if [ "$CHAIN" = "regtest" ]; then
    docker exec bitcoind bash -c "bitcoin-cli -chain=${CHAIN} -rpcuser=${RPCUSER} -rpcpassword=${RPCPASSWORD} -rpcport=${RPCPORT} generatetoaddress 250 ${WALLET_ADDRESS}"
    echo "generating 250 blocks"
fi

sleep 30s & 
pid=$!
spin_wheel "$pid"

echo "Starting cpuminer server"
docker-compose up bitcoin-node-manager -d
docker-compose up cpuminer -d
docker-compose logs --follow
