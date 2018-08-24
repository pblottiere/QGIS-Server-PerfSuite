#! /bin/bash

# env vars
OUTDIR=/tmp/render
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

# run script in each qgis container
rm -rf $OUTDIR
mkdir -p $OUTDIR

TIMEFORMAT=%R  # for time command

CMD_PYTHON2="apt-get install -y python-qt4-sql python-xvfbwrapper && cd /tmp"

CMD_PYTHON3="apt-get install -y python3-xvfbwrapper && cd /tmp"

CMD=" render.py /usr/local postgres /tmp/render.png -host $DOCKER_IP_DATA -db $PG_DB -user $PG_USER -pwd $PG_PASSWORD -geom $GEOM -schema $SCHEMA -table $TABLE -id $VIEW_ID"

# QGIS 2.14
docker cp render.py qgisserver-perfsuite-2.14:/tmp
HEADLESS_2_14=$(docker exec -i qgisserver-perfsuite-2.14 /bin/sh -c "$CMD_PYTHON2 && python2 $CMD" | sed -n "s/^.*Rendering time:\s*\(\S*\).*$/\1/p")
docker cp qgisserver-perfsuite-2.14:/tmp/render.png /tmp/render_2_14.png

SERVER_CACHE_2_14=$( { time curl --silent "http://localhost:8088/qgisserver_2_14?MAP=/data/data_perf.qgs&SERVICE=WMS&REQUEST=GetMap&WIDTH=1629&HEIGHT=800&CRS=EPSG:2154&FORMAT=png&LAYER=$TABLE" > $OUTDIR/server_2_14.png; } 2>&1)
SERVER_2_14=$( { time curl --silent "http://localhost:8088/qgisserver_2_14?MAP=/data/data_perf.qgs&SERVICE=WMS&REQUEST=GetMap&WIDTH=1629&HEIGHT=800&CRS=EPSG:2154&FORMAT=png&LAYER=$TABLE" > $OUTDIR/server_2_14.png; } 2>&1 )

# QGIS 2.18
docker cp render.py qgisserver-perfsuite-2.18:/tmp
HEADLESS_2_18=$(docker exec -i qgisserver-perfsuite-2.18 /bin/sh -c "$CMD_PYTHON2 && python2 $CMD" | sed -n "s/^.*Rendering time:\s*\(\S*\).*$/\1/p")
docker cp qgisserver-perfsuite-2.18:/tmp/render.png /tmp/render_2_18.png

SERVER_CACHE_2_18=$( { time curl --silent "http://localhost:8088/qgisserver_2_18?MAP=/data/data_perf.qgs&SERVICE=WMS&REQUEST=GetMap&WIDTH=1629&HEIGHT=800&CRS=EPSG:2154&FORMAT=png&LAYER=$TABLE" > $OUTDIR/server_2_18.png; } 2>&1)
SERVER_2_18=$( { time curl --silent "http://localhost:8088/qgisserver_2_18?MAP=/data/data_perf.qgs&SERVICE=WMS&REQUEST=GetMap&WIDTH=1629&HEIGHT=800&CRS=EPSG:2154&FORMAT=png&LAYER=$TABLE" > $OUTDIR/server_2_18.png; } 2>&1 )

# QGIS 3.0
docker cp render.py qgisserver-perfsuite-3.0:/tmp
HEADLESS_3_0=$(docker exec -i qgisserver-perfsuite-3.0 /bin/sh -c "$CMD_PYTHON3 && python3 $CMD" | sed -n "s/^.*Rendering time:\s*\(\S*\).*$/\1/p")
docker cp qgisserver-perfsuite-3.0:/tmp/render.png $OUTDIR/headless_3_0.png

SERVER_CACHE_3_0=$( { time curl --silent "http://localhost:8088/qgisserver_3_0?MAP=/data/data_perf.qgs&SERVICE=WMS&REQUEST=GetMap&WIDTH=1629&HEIGHT=800&CRS=EPSG:2154&FORMAT=png&LAYER=$TABLE" > $OUTDIR/server_3_0.png; } 2>&1)
SERVER_3_0=$( { time curl --silent "http://localhost:8088/qgisserver_3_0?MAP=/data/data_perf.qgs&SERVICE=WMS&REQUEST=GetMap&WIDTH=1629&HEIGHT=800&CRS=EPSG:2154&FORMAT=png&LAYER=$TABLE" > $OUTDIR/server_3_0.png; } 2>&1 )

# QGIS MASTER
docker cp render.py qgisserver-perfsuite-master:/tmp
HEADLESS_MASTER=$(docker exec -i qgisserver-perfsuite-master /bin/sh -c "$CMD_PYTHON3 && python3 $CMD" | sed -n "s/^.*Rendering time:\s*\(\S*\).*$/\1/p")
docker cp qgisserver-perfsuite-master:/tmp/render.png $OUTDIR/headless_master.png

SERVER_CACHE_MASTER=$( { time curl --silent "http://localhost:8088/qgisserver_master?MAP=/data/data_perf.qgs&SERVICE=WMS&REQUEST=GetMap&WIDTH=1629&HEIGHT=800&CRS=EPSG:2154&FORMAT=png&LAYER=$TABLE" > $OUTDIR/server_master.png; } 2>&1)
SERVER_MASTER=$( { time curl --silent "http://localhost:8088/qgisserver_master?MAP=/data/data_perf.qgs&SERVICE=WMS&REQUEST=GetMap&WIDTH=1629&HEIGHT=800&CRS=EPSG:2154&FORMAT=png&LAYER=$TABLE" > $OUTDIR/server_master.png; } 2>&1 )

printf "\n\n"
echo "Rendering time for QGIS 2.14:"
echo "        - headless: $HEADLESS_2_14"
echo "        - server 1st request: $SERVER_CACHE_2_14"
echo "        - server 2nd request: $SERVER_2_14"
echo "Rendering time for QGIS 2.18:"
echo "        - headless: $HEADLESS_2_18"
echo "        - server 1st request: $SERVER_CACHE_2_18"
echo "        - server 2nd request: $SERVER_2_18"
echo "Rendering time for QGIS 3.0:"
echo "        - headless: $HEADLESS_3_0"
echo "        - server 1st request: $SERVER_CACHE_3_0"
echo "        - server 2nd request: $SERVER_3_0"
echo "Rendering time for QGIS Master: "
echo "        - headless: $HEADLESS_MASTER"
echo "        - server 1st request: $SERVER_CACHE_MASTER"
echo "        - server 2nd request: $SERVER_MASTER"
printf "\n\n"

# clear containers
cd $ROOT
docker-compose stop
docker-compose rm -f
