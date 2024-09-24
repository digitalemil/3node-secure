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

kubectl wait --for=condition=ready pod -n $NAMESPACE -l component=appserver

kubectl -n $NAMESPACE port-forward deployment/thegym 3031:3000 