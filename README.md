# 3node-secure
A script to install a secure CockroachDB cluster locally

Was 3 nodes is 6 nodes now

Two options available:
* 3 Node cluster on one machine
    * App in docker can be installed
    * export CODE=yourpassword (used when you login to the app)
    * export IPADDR=your_ip_of_the_database which is reachable from within the docker container
    * ./install-thegym.sh
    * Access it on port 3030 (Users: fleur,joe & dude. Password: yourpassword (see above))
* On minikube (in k8s folder)
    * Made and tested in Google Cloud shell
    * Using nginx as proxy to handle redirects which Google Cloud shell doesn't like
    * Include Grafana, Prometheus, Loki & Promtail 
    * Grafana also requires the proxy in Google Cloud shell
    * Access DB Console via port 8080 on "Web
