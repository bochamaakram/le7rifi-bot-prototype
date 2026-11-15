#!/bin/sh
# Start the host backend only after configuration and migrations succeed.
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
python_bin="$project_root/.venv/bin/python"
if [ ! -x "$python_bin" ]; then
    echo 'Create .venv and install backend dependencies first (see README).' >&2
    exit 1
fi
cd "$project_root/backend"
"$python_bin" - <<'PY'
import os
import sys
from dotenv import dotenv_values
from pydantic import ValidationError
from sqlalchemy.engine import make_url
from app.config.settings import get_settings

try:
    settings = get_settings()
except ValidationError as error:
    # Never print Pydantic input dictionaries or database credentials.
    for item in error.errors():
        print(item['msg'], file=sys.stderr)
    sys.exit(1)
dotenv = dotenv_values('../.env')
dotenv.update(dotenv_values('.env'))
supabase_url = os.environ.get('SUPABASE_URL', dotenv.get('SUPABASE_URL'))
if supabase_url and not settings.supabase_database_url and make_url(settings.database_url).host in {'localhost', '127.0.0.1', 'db'}:
    sys.exit('Supabase API keys are configured, but storage still targets a local database. Add SUPABASE_DATABASE_URL to .env using a restricted PostgreSQL role and sslmode=require. See docs/DEPLOYMENT.md.')
print('Configuration valid. Applying database migrations before starting the API.')
PY
"$python_bin" -m alembic upgrade head
exec "$python_bin" -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --no-access-log
