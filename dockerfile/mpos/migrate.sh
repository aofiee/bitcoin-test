#!/bin/bash

# Run the MySQL command and capture the result
# TODO: use service name instead of ip
result=$(mysql -h "${STRATUM_DB_HOST}" -u"${STRATUM_DB_USER}" -p"${STRATUM_DB_PASSWORD}" -Bse "use ${STRATUM_DB_NAME}" 2>&1)

# Check for the presence of the error message
captured_error=$(echo "$result" | grep "(42000)")

# If there is an error, create the database and apply the structure
if [ -n "$captured_error" ]; then
    echo "creating database ${STRATUM_DB_NAME}"
    mysql -h stratumdb -u"${STRATUM_DB_USER}" -p"${STRATUM_DB_PASSWORD}" -Bse "create database ${STRATUM_DB_NAME}" >/dev/null 2>&1
    mysql -h stratumdb -u"${STRATUM_DB_USER}" -p"${STRATUM_DB_PASSWORD}" "${STRATUM_DB_NAME}" < sql/000_base_structure.sql >/dev/null 2>&1
fi