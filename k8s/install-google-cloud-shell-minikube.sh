#!/bin/sh
echo Install for Google Cloud Shell
export GRAFANA_PUBLICPORT=3333
echo WEB_HOST: $WEB_HOST

echo Installing nginx. Access DB console on port 8080. Grafana on port $GRAFANA_PUBLICPORT
export 
envsubst < ../nginx.conf.template >../nginx.conf
sudo apt-get update; sudo apt-get -y install nginx; sudo sudo cp ../nginx.conf /etc/nginx/nginx.conf; sudo nginx

minikube start --cpus=4 --memory=6G

#CRDs
alias k="kubectl --insecure-skip-tls-verify"
kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach-operator/master/install/crds.yaml


#Operator
kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach-operator/master/install/operator.yaml

echo Sleeping 30s...
sleep 30
kubectl wait --for=condition=ready pod -n cockroach-operator-system -l app=cockroach-operator
kubectl wait --for=condition=ready pod -n cockroach-operator-system -l app=cockroach-operator
kubectl wait --for=condition=ready pod -n cockroach-operator-system -l app=cockroach-operator

#CRDB cluster
kubectl create ns cockroachdb
sleep 20
kubectl apply -f cockroachdb.yaml -n cockroachdb

sleep 20
kubectl wait --for=condition=ready pod -n cockroachdb  cockroachdb-2
kubectl wait --for=condition=ready pod -n cockroachdb  cockroachdb-1
kubectl wait --for=condition=ready pod -n cockroachdb  cockroachdb-0

sleep 1
kubectl annotate -n cockroachdb pods cockroachdb-0 prometheus.io/scrape='true' prometheus.io/path='_status/vars' prometheus.io/port='8080'
kubectl annotate -n cockroachdb pods cockroachdb-1 prometheus.io/scrape='true' prometheus.io/path='_status/vars' prometheus.io/port='8080'
kubectl annotate -n cockroachdb pods cockroachdb-2 prometheus.io/scrape='true' prometheus.io/path='_status/vars' prometheus.io/port='8080'
#SQL shell

kubectl create -n cockroachdb -f https://raw.githubusercontent.com/cockroachdb/cockroach-operator/master/examples/client-secure-operator.yaml

kubectl wait --for=condition=ready pod -n cockroachdb  cockroachdb-client-secure

echo Getting certificates. Storing them in cockroach folder
kubectl exec -n "cockroachdb" "cockroachdb-client-secure" -- tar cf - "/cockroach/cockroach-certs" | tar xf - 

echo Creating User me with password me:
kubectl exec -n cockroachdb -it cockroachdb-client-secure -- ./cockroach sql --certs-dir=/cockroach/cockroach-certs --host=cockroachdb-public -e "CREATE USER me WITH PASSWORD 'me';"

echo Access sql shell in another shell:
echo kubectl exec -n cockroachdb -it cockroachdb-client-secure -- ./cockroach sql --certs-dir=/cockroach/cockroach-certs --host=cockroachdb-public

echo Installing Prometheus:
kubectl create ns monitoring
kubectl apply -n monitoring -f prometheus.yaml
kubectl  rollout status -w deployment -n monitoring prometheus-deployment --timeout=90s 

envsubst < grafana.ini.template >./grafana.ini
kubectl create configmap cloudshell-config --from-file=./grafana.ini  --namespace=monitoring
kubectl apply -f grafana.yaml --namespace=monitoring

kubectl port-forward -n monitoring svc/prometheus 9090:9091 &
kubectl port-forward -n monitoring svc/grafana 3030:3000 &

kubectl port-forward -n cockroachdb svc/cockroachdb 18080:8080 