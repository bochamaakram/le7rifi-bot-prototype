"""Create an isolated, expiring tester credential. Does not contact any service."""
import argparse
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import urlparse

import jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--issuer', required=True, help='HTTPS API origin, e.g. https://api.example.com')
    parser.add_argument('--output', type=Path, default=Path('artifacts/hosted-auth'))
    args = parser.parse_args()
    issuer = args.issuer.rstrip('/')
    parsed = urlparse(issuer)
    if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment or parsed.path:
        parser.error('--issuer must be an HTTPS origin without credentials, query or path')

    # Never overwrite signing keys or tokens created by a previous invocation.
    args.output.mkdir(mode=0o700, parents=True, exist_ok=False)
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    private = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption())
    public = key.public_key().public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo).decode()
    now = datetime.now(timezone.utc)
    token = jwt.encode({'iss': issuer, 'aud': 'le7rayfi-mobile', 'sub': 'demo-artisan',
                        'tenant_id': 'demo-tenant', 'iat': now, 'exp': now + timedelta(days=7)}, private, algorithm='RS256')
    env = ("ENVIRONMENT=production\nAUTH_MODE=jwt\nSAAS_MODE=mock\n"
           f"JWT_ISSUER='{issuer}'\nJWT_AUDIENCE=le7rayfi-mobile\nJWT_PUBLIC_KEY='{public}'\n")
    for name, data in [('private.pem', private), ('public.pem', public.encode()),
                       ('backend.env', env.encode()), ('tester-token.txt', token.encode())]:
        path = args.output / name
        with path.open('xb') as stream:
            path.chmod(0o600)
            stream.write(data)
    print(f'Created credentials in {args.output}. Tester token expires in 7 days.')
    print('Keep private.pem local. Copy backend.env settings to the host and tester-token.txt into the app login.')


if __name__ == '__main__':
    main()
