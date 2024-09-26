#!/bin/sh
if [[ -z "${PASSWORD}" ]]; then
  echo Please verify necessary environment variables a set \(SQL user \"me\" PASSWORD\).
  exit -1
fi


echo Install for Google Cloud Shell
export GRAFANA_PUBLICPORT=3333
echo WEB_HOST: $WEB_HOST

echo Installing nginx. Access DB console on port 8080. Grafana on port $GRAFANA_PUBLICPORT

envsubst '${WEB_HOST},${GRAFANA_PUBLICPORT}' < ../nginx.conf.template >../nginx.conf
sudo apt-get update; sudo apt-get -y install nginx; sudo sudo cp ../nginx.conf /etc/nginx/nginx.conf; sudo nginx

minikube start --cpus=4 --memory=6G

#CRDs
alias k="kubectl --insecure-skip-tls-verify"
kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach-operator/master/install/crds.yaml


#Operator
kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach-operator/master/install/operator.yaml

echo Sleeping 60s...
sleep 60
kubectl wait --for=condition=ready pod -n cockroach-operator-system -l app=cockroach-operator  --timeout=120s

#CRDB cluster
kubectl create ns cockroachdb
kubectl apply -f cockroachdb.yaml -n cockroachdb
sleep 20
kubectl apply -f cockroachdb.yaml -n cockroachdb

sleep 20
kubectl wait --for=condition=ready pod -n cockroachdb  cockroachdb-2  --timeout=120s

sleep 1
kubectl annotate -n cockroachdb pods cockroachdb-0 prometheus.io/scrape='true' prometheus.io/path='_status/vars' prometheus.io/port='8080'
kubectl annotate -n cockroachdb pods cockroachdb-1 prometheus.io/scrape='true' prometheus.io/path='_status/vars' prometheus.io/port='8080'
kubectl annotate -n cockroachdb pods cockroachdb-2 prometheus.io/scrape='true' prometheus.io/path='_status/vars' prometheus.io/port='8080'
#SQL shell

kubectl create -n cockroachdb -f https://raw.githubusercontent.com/cockroachdb/cockroach-operator/master/examples/client-secure-operator.yaml

kubectl wait --for=condition=ready pod -n cockroachdb  cockroachdb-client-secure  --timeout=120s

echo Getting certificates. Storing them in cockroach folder
kubectl exec -n "cockroachdb" "cockroachdb-client-secure" -- tar cf - "/cockroach/cockroach-certs" | tar xf - 

echo Creating User me with password me:
kubectl exec -n cockroachdb -it cockroachdb-client-secure -- ./cockroach sql --certs-dir=/cockroach/cockroach-certs --host=cockroachdb-public -e "CREATE USER me WITH PASSWORD '$PASSWORD';"
kubectl exec -n cockroachdb -it cockroachdb-client-secure -- ./cockroach sql --certs-dir=/cockroach/cockroach-certs --host=cockroachdb-public -e "GRANT ALL ON * TO me;"

echo Access sql shell in another shell:
echo kubectl exec -n cockroachdb -it cockroachdb-client-secure -- ./cockroach sql --certs-dir=/cockroach/cockroach-certs --host=cockroachdb-public

echo Installing Loki \& Promtail:
kubectl create ns monitoring
helm repo add grafana  https://grafana.github.io/helm-charts
helm repo update
helm install -n monitoring --values loki.yaml loki grafana/loki
kubectl apply -n monitoring -f promtail.yaml

echo Installing Prometheus:
kubectl apply -n monitoring -f prometheus.yaml

echo Installing Grafana:
envsubst '${PASSWORD}' < ./datasources.yaml.template  >./datasources.yaml 
kubectl create configmap -n monitoring grafana-datasources --from-file=datasources.yaml 
kubectl create configmap -n monitoring grafana-dashboards-definition --from-file=dashboards 
kubectl apply -n monitoring -f dashboards.yaml

kubectl apply -f grafana.yaml --namespace=monitoring
sleep 30

kubectl rollout status -w deployment -n monitoring prometheus-deployment --timeout=120s 
kubectl port-forward -n monitoring svc/prometheus 9090:9091 &

kubectl wait --for=condition=ready pod -n monitoring -l app=grafana --timeout=360s

kubectl port-forward -n monitoring svc/grafana 3030:3000 &

echo Scale: Set the number of requires nodes in cockroachdb.yaml e.g. nodes: 4 and then run kubectl apply -n cockroachdb -f cockroachdb.yaml
echo Or: kubectl scale statefulset cockroachdb -n cockroachdb --replicas=3
kubectl port-forward -n cockroachdb svc/cockroachdb 18080:8080 