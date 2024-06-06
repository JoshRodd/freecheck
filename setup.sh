#!/bin/bash

if ! which gs; then
    brew install ghostscript || exit
fi
./add_fonts.sh
if ! which python3; then
    brew install python3 || exit
fi
if [ ! -d .venv/ ]; then python3 -m venv .venv || exit; fi
. .venv/bin/activate
python3 -m pip install -r requirements.txt | grep -v '^Requirement already satisfied: '
python3 -m pip install -r test_requirements.txt | grep -v '^Requirement already satisfied: '
echo Before running any commands, remember to:
echo -e '\t'. .venv/bin/activate
echo
echo For an end to end test run:
echo -e '\t'pytest
echo
echo For sample output:
echo
echo -e '\t'cp freecheck.toml \~
echo -e '\t'./freecheck.py \| ps2pdf - sample.pdf
echo
echo and then open or print the sample.pdf file.
