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

cd $WORKDIR

# install deps
apt-get install -y libffi-dev virtualenv curl

if [ $PYTHON_VERSION -eq 2 ]
then
  echo "1"
elif [ $PYTHON_VERSION -eq 3 ]
then
  apt-get install -y python3-virtualenv python3-xvfbwrapper python3-pip
fi

# install graffiti
git clone https://github.com/pblottiere/graffiti
cd graffiti
mkdir venv
virtualenv --system-site-packages -p /usr/bin/python$PYTHON_VERSION ./venv
. venv/bin/activate
pip install -r requirements.txt

# run renderer
cp ../headless.py .

python$PYTHON_VERSION headless.py /usr/local postgres /tmp/headless.png \
	-pg-host $DB_HOST -pg-db $DB -pg-user $USER -pg-pwd $PSWD -pg-geom $GEOM \
	-pg-schema $SCHEMA -pg-table $TABLE --server -server-host $SERVER_HOST

ls /tmp/*.png
