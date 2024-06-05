#!/bin/bash

brew install ghostscript
#utilities/add_fonts.sh
if [ ! -d .venv/ ]; then python3 -m venv .venv; fi
. .venv/bin/activate
python3 -m pip install -r requirements.txt | grep -v '^Requirement already satisfied: '
python3 -m pip install -r test_requirements.txt | grep -v '^Requirement already satisfied: '
echo Before running any commands, remember to:
echo -e '\t'. .venv/bin/activate
