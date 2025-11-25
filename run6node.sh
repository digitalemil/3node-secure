#!/bin/sh

# delete old install
#./cleanup.sh

# mdkir for certificates
mkdir certs my-safe-directory

UNAME=$(uname)
echo Installing for: $UNAME
# Download binary MacOS Arm or Linux x86
if [[ "$UNAME" == "Darwin" ]]; then
    curl -LJO https://binaries.cockroachdb.com/cockroach-v25.4.0.darwin-10.9-amd64.tgz
    mv cockroach-v25.*.darwin* cockroach.tgz
else
    curl -LJO https://binaries.cockroachdb.com/cockroach-v25.4.0.linux-amd64.tgz
    mv cockroach-v24.*.linux-amd64.tgz cockroach.tgz
    # Only needed for Google Cloud Shell
    sudo apt-get update; sudo apt-get -y install nginx; sudo sudo cp nginx.conf /etc/nginx/nginx.conf; sudo nginx
fi

tar xzf cockroach.tgz
mv cockroach-* cockroach
#rm cockroach.tgz

# Create the CA (Certificate Authority) certificate and key pair:
./cockroach/cockroach cert create-ca --certs-dir=certs --ca-key=my-safe-directory/ca.key
# Create the certificate and key pair for your nodes
./cockroach/cockroach cert create-node localhost $(hostname) 0.0.0.0 --certs-dir=certs --ca-key=my-safe-directory/ca.key
# Create a client certificate and key pair for the root user
./cockroach/cockroach cert create-client root --certs-dir=certs --ca-key=my-safe-directory/ca.key

# Start node 1
./cockroach/cockroach start --certs-dir=certs --locality=region=europe,rack=rack1 --store=node1 --listen-addr=0.0.0.0:27257 --sql-addr=0.0.0.0:28257 --http-addr=0.0.0.0:18080 --join=localhost:27257,localhost:27258,localhost:27259 &

# Start node 2
./cockroach/cockroach start --certs-dir=certs --locality=region=europe,rack=rack2 --store=node2 --listen-addr=0.0.0.0:27258 --sql-addr=0.0.0.0:28258 --http-addr=0.0.0.0:18081 --join=localhost:27257,localhost:27258,localhost:27259 &

# Start node 3
./cockroach/cockroach start --certs-dir=certs --locality=region=europe,rack=rack3 --store=node3 --listen-addr=0.0.0.0:27259 --sql-addr=0.0.0.0:28259 --http-addr=0.0.0.0:18082 --join=localhost:27257,localhost:27258,localhost:27259 &

# Init cluster
sleep 12 
./cockroach/cockroach init --certs-dir=certs --host=localhost:27257

sleep 4

# Create user me with password me
./cockroach/cockroach sql --certs-dir=certs   --host=localhost:28257 -e "ALTER RANGE default CONFIGURE ZONE USING num_replicas = 5, gc.ttlseconds = 100000;"
./cockroach/cockroach sql --certs-dir=certs   --host=localhost:28257 -e "CREATE USER me WITH PASSWORD 'me';"

echo You can access the DB Console on port 18080-18082
#echo 
./cockroach/cockroach start --certs-dir=certs --locality=region=europe,rack=rack1 --store=node4 --listen-addr=0.0.0.0:27260 --sql-addr=0.0.0.0:28260 --http-addr=0.0.0.0:18083 --join=localhost:27257,localhost:27258,localhost:27259 &
sleep 4
./cockroach/cockroach start --certs-dir=certs --locality=region=europe,rack=rack2 --store=node5 --listen-addr=0.0.0.0:27261 --sql-addr=0.0.0.0:28261 --http-addr=0.0.0.0:18084 --join=localhost:27257,localhost:27258,localhost:27259 &
sleep 4
./cockroach/cockroach start --certs-dir=certs --locality=region=europe,rack=rack3 --store=node6 --listen-addr=0.0.0.0:27262 --sql-addr=0.0.0.0:28262 --http-addr=0.0.0.0:18085 --join=localhost:27257,localhost:27258,localhost:27259 &
#echo 
# Open sql shell
sleep 8
./cockroach/cockroach sql --certs-dir=certs --host=localhost:28257

# Kill all after sql shell exit
cleanup() {
    # kill all processes whose parent is this process
    pkill -9 -P $$
}
trap cleanup EXIT
