#!/bin/bash

# Run the MySQL command and capture the result
# TODO: use service name instead of ip
result=$(mysql -h stratumdb -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -Bse "use ${MYSQL_DATABASE}" 2>&1)

# Check for the presence of the error message
captured_error=$(echo "$result" | grep "(42000)")

# If there is an error, create the database and apply the structure
if [ -n "$captured_error" ]; then
    echo "creating database ${MYSQL_DATABASE}"
    mysql -h stratumdb -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -Bse "create database ${MYSQL_DATABASE}" >/dev/null 2>&1
    mysql -h stratumdb -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" ${MYSQL_DATABASE} < sql/000_base_structure.sql >/dev/null 2>&1
fi