./cockroach/cockroach init --certs-dir=certs --host=localhost:27257
./cockroach/cockroach sql --certs-dir=certs   --host=localhost:28257 -e "CREATE USER me WITH PASSWORD 'me';"
./cockroach/cockroach sql --certs-dir=certs   --host=localhost:28257 -e "ALTER RANGE default CONFIGURE ZONE USING num_replicas = 5, gc.ttlseconds = 100000;"
