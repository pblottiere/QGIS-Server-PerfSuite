#! /bin/bash

# env vars
PG_USER=root
PG_PASSWORD=root
PG_DB=data
TABLE=hydro_lake
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
CMD_PYTHON2="apt-get install -y python-qt4-sql python-xvfbwrapper && cd /tmp"

CMD_PYTHON3="apt-get install -y python3-xvfbwrapper && cd /tmp"

CMD=" render.py /usr/local postgres /tmp/render.png -host $DOCKER_IP_DATA -db $PG_DB -user $PG_USER -pwd $PG_PASSWORD -geom $GEOM -schema $SCHEMA -table $TABLE -id $VIEW_ID"

docker cp render.py qgisserver-perfsuite-2.14:/tmp
TIME_2_14=$(docker exec -i qgisserver-perfsuite-2.14 /bin/sh -c "$CMD_PYTHON2 && python2 $CMD" | sed -n "s/^.*Rendering time:\s*\(\S*\).*$/\1/p")
rm -f /tmp/render_2_14.png
docker cp qgisserver-perfsuite-2.14:/tmp/render.png /tmp/render_2_14.png

docker cp render.py qgisserver-perfsuite-2.18:/tmp
TIME_2_18=$(docker exec -i qgisserver-perfsuite-2.18 /bin/sh -c "$CMD_PYTHON2 && python2 $CMD" | sed -n "s/^.*Rendering time:\s*\(\S*\).*$/\1/p")
rm -f /tmp/render_2_18.png
docker cp qgisserver-perfsuite-2.18:/tmp/render.png /tmp/render_2_18.png

docker cp render.py qgisserver-perfsuite-3.0:/tmp
TIME_3_0=$(docker exec -i qgisserver-perfsuite-3.0 /bin/sh -c "$CMD_PYTHON3 && python3 $CMD" | sed -n "s/^.*Rendering time:\s*\(\S*\).*$/\1/p")
rm -f /tmp/render_3_0.png
docker cp qgisserver-perfsuite-3.0:/tmp/render.png /tmp/render_3_0.png

docker cp render.py qgisserver-perfsuite-master:/tmp
TIME_MASTER=$(docker exec -i qgisserver-perfsuite-master /bin/sh -c "$CMD_PYTHON3 && python3 $CMD" | sed -n "s/^.*Rendering time:\s*\(\S*\).*$/\1/p")
rm -f /tmp/render_master.png
docker cp qgisserver-perfsuite-master:/tmp/render.png /tmp/render_master.png

echo "\n\n"
echo "Rendering time for QGIS 2.14: $TIME_2_14"
echo "Rendering time for QGIS 2.18: $TIME_2_18"
echo "Rendering time for QGIS 3.0: $TIME_3_0"
echo "Rendering time for QGIS Master: $TIME_MASTER"
echo "\n\n"

# clear containers
cd $ROOT
docker-compose stop
docker-compose rm -f
