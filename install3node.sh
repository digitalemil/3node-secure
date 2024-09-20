#!/bin/sh

# delete old install
./cleanup.sh

# mdkir for certificates
mkdir certs my-safe-directory

UNAME=$(uname)
echo Installing for: $UNAME
# Download binary MacOS Arm or Linux x86
if [[ "$UNAME" == "Darwin" ]]; then
    curl -LJO https://binaries.cockroachdb.com/cockroach-v24.2.0.darwin-11.0-arm64.tgz
    mv cockroach-v24.2.0.darwin-11.0-arm64.tgz cockroach.tgz
else
    curl -LJO https://binaries.cockroachdb.com/cockroach-v24.2.0.linux-amd64.tgz
    mv cockroach-v24.2.0.linux-amd64.tgz cockroach.tgz
fi

tar xzf cockroach.tgz
mv cockroach-* cockroach
rm cockroach.tgz

# Create the CA (Certificate Authority) certificate and key pair:
./cockroach/cockroach cert create-ca --certs-dir=certs --ca-key=my-safe-directory/ca.key
# Create the certificate and key pair for your nodes
./cockroach/cockroach cert create-node localhost $(hostname) --certs-dir=certs --ca-key=my-safe-directory/ca.key
# Create a client certificate and key pair for the root user
./cockroach/cockroach cert create-client root --certs-dir=certs --ca-key=my-safe-directory/ca.key

# Start node 1
./cockroach/cockroach start --certs-dir=certs --store=node1 --listen-addr=:27257 --sql-addr=:26257 --http-addr=:8080 --join=localhost:27257,localhost:27258,localhost:27259 &

# Start node 2
./cockroach/cockroach start --certs-dir=certs --store=node2 --listen-addr=:27258 --sql-addr=:26258 --http-addr=:8081 --join=localhost:27257,localhost:27258,localhost:27259 &

# Start node 3
./cockroach/cockroach start --certs-dir=certs --store=node3 --listen-addr=:27259 --sql-addr=:26259 --http-addr=:8082 --join=localhost:27257,localhost:27258,localhost:27259 &

# Init cluster
sleep 6
./cockroach/cockroach init --certs-dir=certs --host=localhost:27257

sleep 2
# Create user
./cockroach/cockroach sql --certs-dir=certs --host=localhost:26257 -e "CREATE USER me WITH PASSWORD 'me';"

# Print Scale-out command
echo
echo You can access the DB Console on port 8080-8082
echo 
echo To add node 4: Open another shell and execute:
echo ./cockroach/cockroach start --certs-dir=certs --store=node4 --listen-addr=:27260 --sql-addr=:26260 --http-addr=:8083 --join=localhost:27257,localhost:27258,localhost:27259
echo 

# Open sql shell
./cockroach/cockroach sql --certs-dir=certs --host=localhost:26257

# Kill all after sql shell exit
cleanup() {
    # kill all processes whose parent is this process
    pkill -9 -P $$
}
trap cleanup EXIT