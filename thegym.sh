#!/bin/sh

if [[ -z "${CODE}" ]]; then
  echo Please verify necessary environment variables a set \(CODE\).
  exit -1
fi

if [[ -z "${IPADDR}" ]]; then
  echo Please verify necessary environment variables a set \(IPADDR\).
  exit -1
fi

export DATABASE_CONNECTIONSTRING="postgresql://root@$IPADDR:26257/defaultdb?sslmode=verify-full&sslrootcert=/tmp/certs/ca.crt&sslcert=/tmp/certs/client.root.crt&sslkey=/tmp/certs/client.root.key"

docker run -p 3030:3000 -v $(pwd)/certs:/tmp/certs -e DATABASE_CONNECTIONSTRING="$DATABASE_CONNECTIONSTRING" -e CODE=$CODE digitalemil/sourdough:thegym-vlatest