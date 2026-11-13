#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python -m compileall -q backend evaluation scripts
PYTHONPATH=backend python -m unittest discover -s backend/tests -p test_domain.py -v
PYTHONPATH=backend python -m unittest discover -s backend/tests -p test_body_limit.py -v
python -m unittest discover -s evaluation -p test_evaluate.py -v
(cd backend && python -m pytest)
(cd mobile && flutter pub get && flutter analyze && flutter test)
