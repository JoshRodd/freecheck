#!/bin/bash

./setup.sh

. .venv/bin/activate

if ! which black; then
    python3 -m pip install black | grep -v '^Requirement already satisfied: '
fi

if ! which ruff; then
    python3 -m pip install ruff | grep -v '^Requirement already satisfied: '
fi

pytest &&
black . &&
ruff check . &&
poetry export &&
poetry export --with test -o test_requirements.txt &&
poetry build
