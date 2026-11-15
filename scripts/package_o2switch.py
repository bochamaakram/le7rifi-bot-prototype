"""Build an allowlisted source archive; never includes local settings or keys."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


def build_archive(root: Path, output: Path):
    files = [root / 'backend' / name for name in ('pyproject.toml', 'alembic.ini', 'passenger_wsgi.py')]
    for directory in ('backend/app', 'backend/migrations'):
        files.extend(path for path in (root / directory).rglob('*.py') if '__pycache__' not in path.parts)
    files.append(root / 'docs/O2SWITCH.md')
    output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(output, 'w', ZIP_DEFLATED) as archive:
        for path in sorted(files):
            if path.is_symlink():
                raise ValueError('Deployment source must not contain symlinks')
            archive.write(path, path.relative_to(root))
    return len(files)


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    output = root / 'artifacts/le7rayfi-o2switch.zip'
    count = build_archive(root, output)
    print(f'Packaged {count} source files: {output}')
    print('Secrets are excluded. Configure them privately on the host.')
