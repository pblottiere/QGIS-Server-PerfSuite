#! /bin/bash

# env vars
OUTDIR=/tmp/headless
PG_USER=root
PG_PASSWORD=root
PG_DB=data
TABLE=hydro_segment
SCHEMA=ref
GEOM=geoml93
VIEW_ID=none

ROOT=$PWD
if [ $# -eq 1 ]
then
    ROOT=$1
fi

# download data
if [ ! -d "$ROOT/data" ]
then
  sh download.sh
fi

# start servers
cd $ROOT
docker-compose up -d

# get ip for containers
DOCKER_IP_DATA=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' qgisserver-perfsuite-data)

# wait for postgres to be ready
until PGPASSWORD=$PG_PASSWORD psql -h $DOCKER_IP_DATA -U $PG_USER -d $PG_DB -c '\q'
do
  >&2 echo "Data container is unavailable - sleeping"
  sleep 10
done

rm -rf $OUTDIR
mkdir -p $OUTDIR

# QGIS 2.14
echo "QGIS 2.14"
docker cp headless.py qgisserver-perfsuite-2.14:/tmp
docker cp headless.sh qgisserver-perfsuite-2.14:/tmp

docker exec -i qgisserver-perfsuite-2.14 /bin/bash -c "bash /tmp/headless.sh 2 $DOCKER_IP_DATA http://nginx/qgisserver_2_14" > $OUTDIR/2_14.log

docker cp qgisserver-perfsuite-2.14:/tmp/headless_0_layer.png $OUTDIR/2_14_postgres_headless.png
docker cp qgisserver-perfsuite-2.14:/tmp/headless_1_adress_ban.png $OUTDIR/2_14_qgs_headless.png
docker cp qgisserver-perfsuite-2.14:/tmp/server_host.png $OUTDIR/2_14_server.png

# QGIS 2.18
echo "QGIS 2.18"
docker cp headless.py qgisserver-perfsuite-2.18:/tmp
docker cp headless.sh qgisserver-perfsuite-2.18:/tmp

docker exec -i qgisserver-perfsuite-2.18 /bin/bash -c "bash /tmp/headless.sh 2 $DOCKER_IP_DATA http://nginx/qgisserver_2_18" > $OUTDIR/2_18.log

docker cp qgisserver-perfsuite-2.18:/tmp/headless_0_layer.png $OUTDIR/2_18_postgres_headless.png
docker cp qgisserver-perfsuite-2.18:/tmp/headless_1_adress_ban.png $OUTDIR/2_18_qgs_headless.png
docker cp qgisserver-perfsuite-2.18:/tmp/server_host.png $OUTDIR/2_18_server.png

# QGIS 3.0
echo "QGIS 3.0"
docker cp headless.py qgisserver-perfsuite-3.0:/tmp
docker cp headless.sh qgisserver-perfsuite-3.0:/tmp

docker exec -i qgisserver-perfsuite-3.0 /bin/sh -c "sh /tmp/headless.sh 3 $DOCKER_IP_DATA http://nginx/qgisserver_3_0" > $OUTDIR/3_0.log

docker cp qgisserver-perfsuite-3.0:/tmp/headless_0_layer.png $OUTDIR/3_0_postgres_headless.png
docker cp qgisserver-perfsuite-3.0:/tmp/headless_1_adress_ban.png $OUTDIR/3_0_qgs_headless.png
docker cp qgisserver-perfsuite-3.0:/tmp/server_host.png $OUTDIR/3_0_server.png

# QGIS MASTER
echo "QGIS Master"
docker cp headless.py qgisserver-perfsuite-master:/tmp
docker cp headless.sh qgisserver-perfsuite-master:/tmp

docker exec -i qgisserver-perfsuite-master /bin/sh -c "sh /tmp/headless.sh 3 $DOCKER_IP_DATA http://nginx/qgisserver_master" > $OUTDIR/master.log

docker cp qgisserver-perfsuite-master:/tmp/headless_0_layer.png $OUTDIR/master_postgres_headless.png
docker cp qgisserver-perfsuite-master:/tmp/headless_1_adress_ban.png $OUTDIR/master_qgs_headless.png
docker cp qgisserver-perfsuite-master:/tmp/server_host.png $OUTDIR/master_server.png

# clear containers
cd $ROOT
docker-compose stop
docker-compose rm -f
