#!/bin/sh

if [[ -z "${CODE}" ]]; then
  echo Please verify necessary environment variables a set \(CODE\).
  exit -1
fi

export DATABASE_CONNECTIONSTRING='postgresql://root@cockroachdb-public.cockroachdb:26257/defaultdb?sslmode=verify-full&sslrootcert=/tmp/cert1/ca.crt&sslcert=/tmp/cert2/client.root.crt&sslkey=/tmp/cert3/client.root.key'
export NAMESPACE=thegym

kubectl create ns $NAMESPACE

kubectl -n $NAMESPACE create configmap sslkey --from-file ./cockroach/cockroach-certs/client.root.key
kubectl -n $NAMESPACE create configmap sslcert --from-file ./cockroach/cockroach-certs/client.root.crt
kubectl -n $NAMESPACE create configmap sslrootcert --from-file ./cockroach/cockroach-certs/ca.crt

envsubst < thegym.yaml | kubectl apply -n $NAMESPACE -f -

kubectl wait --for=condition=ready pod -n $NAMESPACE -l component=appserver  --timeout=360s

kubectl exec -n cockroachdb -it cockroachdb-client-secure -- ./cockroach sql --certs-dir=/cockroach/cockroach-certs --host=cockroachdb-public -e "drop view hrg;  create view HRG as select CAST(json->'doc'->'svg'->>'timestamp' AS TIMESTAMP) as id, CAST(json->'doc'->'svg'->>'heartrate' AS INT) as  hr , CAST(json->'doc'->'svg'->>'speed' AS FLOAT)  as speed, CAST(json->'doc'->'svg'->>'latitude' AS FLOAT)  as latitude, CAST(json->'doc'->'svg'->>'longitude' AS FLOAT)  as longitude , json->'doc'->'svg'->>'username' as username, json->'doc'->'svg'->>'deviceid' as deviceid, json->'doc'->'svg'->>'manufacturer' as manufacturer, json->'doc'->'svg'->>'devicetype' as devicetype  from Heartrates; GRANT ALL ON * TO me;"

kubectl -n $NAMESPACE port-forward deployment/thegym 3031:3000
