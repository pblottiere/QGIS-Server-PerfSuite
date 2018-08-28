#! /bin/bash

OUTDIR=/tmp/perfsuite-summary

# run graffiti
if [ ! -d "graffiti" ]
then
  git clone https://github.com/pblottiere/graffiti
  cd graffiti
  mkdir venv
  virtualenv -p /usr/bin/python3 ./venv
  . venv/bin/activate
  pip install -e .
  deactivate
  cd -
fi

. graffiti/venv/bin/activate

export PYTHONPATH=$PWD/graffiti

rm -rf $OUTDIR
mkdir -p $OUTDIR
python3 summary.py $PWD/../scenarios/scenarios.yml $HOME/.perfsuite $OUTDIR

deactivate
