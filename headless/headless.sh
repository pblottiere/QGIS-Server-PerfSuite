#! /bin/bash

PYTHON_VERSION=$1
DB_HOST=$2
SERVER_HOST=$3

WORKDIR=/tmp
DB=data
USER=root
PSWD=root
SCHEMA=ref
TABLE=adress_ban
GEOM=geom
PROJECT=/data/data_perf.qgs
EXTENT="516450.22,6233455.70,622889.37,6314442.24"

export PYTHONPATH=/usr/local/share/qgis/python
export LD_LIBRARY_PATH=/usr/local/lib

cd $WORKDIR
 
# install deps
apt-get install -y libffi-dev virtualenv 
 
if [ $PYTHON_VERSION -eq 2 ]
then
apt-get install -y python-virtualenv python-xvfbwrapper python-pip python-qt4-sql
elif [ $PYTHON_VERSION -eq 3 ]
then
  apt-get install -y python3-virtualenv python3-xvfbwrapper python3-pip
fi
 
# install graffiti
git clone https://github.com/pblottiere/graffiti
cd graffiti

if [ $PYTHON_VERSION -eq 2 ]
then
  git checkout python2
fi

virtualenv --system-site-packages -p /usr/bin/python$PYTHON_VERSION ./venv
. venv/bin/activate
pip install -r requirements.txt

# run renderer
cp ../headless.py .

python$PYTHON_VERSION headless.py /usr/local $EXTENT /tmp/ \
	--pg -pg-host $DB_HOST -pg-db $DB -pg-user $USER -pg-pwd $PSWD -pg-geom $GEOM -pg-schema $SCHEMA -pg-table $TABLE \
	--server -server-host $SERVER_HOST -server-layer $TABLE -server-project $PROJECT \
	--qgs --qgs-file $PROJECT --qgs-layer $TABLE

ls /tmp/*.png
