#!/bin/bash

set -e

echo "-- sap-to-gedemin image"
docker build --no-cache -t sap-to-gedemin .

echo
echo "-- Testing server is running"
docker run --name app -d -p 8888:8080 sap-to-gedemin; sleep 4
curl 127.0.0.1:8888/phpinfo.php 2>/dev/null | grep -c "PHP Version 7.2"
docker exec -it app php -v | grep -c 'PHP 7.2'

echo
echo "-- Clear"
docker rm -f -v app; sleep 5
docker rmi -f sap-to-gedemin
