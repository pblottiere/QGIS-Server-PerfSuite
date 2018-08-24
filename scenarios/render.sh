#! /bin/bash

# env vars
PG_USER=root
PG_PASSWORD=root
PG_DB=data

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
CMD="apt-get install -y python3-xvfbwrapper && cd /tmp && python3 render.py /usr/local postgres /tmp/coucou.png -host $DOCKER_IP_DATA -db $PG_DB -user $PG_USER -pwd $PG_PASSWORD -geom geoml93 -schema ref -table hydro_bassin"

docker cp render.py qgisserver-perfsuite-3.0:/tmp
docker exec -it qgisserver-perfsuite-3.0 /bin/sh -c "$CMD"

docker cp render.py qgisserver-perfsuite-master:/tmp
docker exec -it qgisserver-perfsuite-master /bin/sh -c "$CMD"

# clear containers
cd $ROOT
docker-compose stop
docker-compose rm -f
