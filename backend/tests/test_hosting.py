"""Hosting smoke checks with no external database or provider requests."""
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
from wsgiref.util import setup_testing_defaults
from zipfile import ZipFile

import jwt
import pytest
from fastapi.security import HTTPAuthorizationCredentials

from app.auth.identity import authenticate
from app.config.settings import Settings

ROOT = Path(__file__).resolve().parents[2]


def load_script(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / f'{name}.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def request(application, path, body=b''):
    environ = {}
    setup_testing_defaults(environ)
    environ.update(PATH_INFO=path, REQUEST_METHOD='POST' if body else 'GET',
                   CONTENT_LENGTH=str(len(body)), **{'wsgi.input': io.BytesIO(body)})
    status = []
    headers = {}

    def start_response(value, items, exc_info=None):
        status.append(value)
        headers.update((key.lower(), value) for key, value in items)

    response = application(environ, start_response)
    try:
        data = b''.join(response)
    finally:
        if hasattr(response, 'close'):
            response.close()
    return int(status[0].split()[0]), headers, json.loads(data)


def test_passenger_health_auth_and_upload_limit(monkeypatch):
    pytest.importorskip('a2wsgi')
    from app import passenger
    settings = Settings(_env_file=None, environment='production', auth_mode='jwt',
                        jwt_issuer='https://api.invalid', jwt_audience='mobile', jwt_public_key='test-only')
    monkeypatch.setattr(passenger, 'get_settings', lambda: settings)
    application = passenger.create_application()
    code, headers, data = request(application, '/health')
    assert code == 200 and data == {'status': 'ok'}
    assert headers['cache-control'] == 'no-store'
    assert request(application, '/api/v1/me')[0] == 401
    assert request(application, '/api/v1/speech/transcribe', b'x' * 5_000_001)[0] == 413


def test_passenger_refuses_development_login(monkeypatch):
    pytest.importorskip('a2wsgi')
    from app import passenger
    monkeypatch.setattr(passenger, 'get_settings', lambda: Settings(_env_file=None))
    with pytest.raises(RuntimeError, match='AUTH_MODE=jwt'):
        passenger.create_application()


def test_hosted_tester_works_with_existing_validator_and_does_not_overwrite(tmp_path):
    output = tmp_path / 'credentials'
    command = [sys.executable, str(ROOT / 'scripts/create_hosted_tester.py'),
               '--issuer', 'https://api.example.test', '--output', str(output)]
    result = subprocess.run(command, capture_output=True, text=True)
    assert result.returncode == 0
    token = (output / 'tester-token.txt').read_text()
    settings = Settings(_env_file=output / 'backend.env', environment='production', auth_mode='jwt')
    identity = authenticate(HTTPAuthorizationCredentials(scheme='Bearer', credentials=token), settings)
    assert (identity.tenant_id, identity.user_id) == ('demo-tenant', 'demo-artisan')
    claims = jwt.decode(token, settings.jwt_public_key, algorithms=['RS256'],
                        audience=settings.jwt_audience, issuer=settings.jwt_issuer)
    assert claims['exp'] - claims['iat'] == 7 * 24 * 3600
    assert token not in result.stdout
    assert (output / 'private.pem').stat().st_mode & 0o777 == 0o600
    assert subprocess.run(command, capture_output=True).returncode != 0
    assert (output / 'tester-token.txt').read_text() == token


def test_upload_archive_excludes_credentials_and_builds(tmp_path):
    root = tmp_path / 'source'
    backend = root / 'backend'
    for directory in ('app', 'migrations', 'app/__pycache__'):
        (backend / directory).mkdir(parents=True, exist_ok=True)
    for name in ('pyproject.toml', 'alembic.ini', 'passenger_wsgi.py', 'app/main.py', 'migrations/env.py'):
        (backend / name).write_text('fixture')
    for name in ('.env', 'private.pem', 'app/__pycache__/secret.py'):
        (backend / name).write_text('private data')
    (root / 'docs').mkdir()
    (root / 'docs/O2SWITCH.md').write_text('instructions')
    output = tmp_path / 'upload.zip'
    load_script('package_o2switch').build_archive(root, output)
    with ZipFile(output) as archive:
        assert 'backend/passenger_wsgi.py' in archive.namelist()
        assert all(b'private data' not in archive.read(name) for name in archive.namelist())
