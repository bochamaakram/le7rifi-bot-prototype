# SaaS integration — proposed, not a live contract

Only the explicitly labeled `MockSaaSAdapter` is active. `RealSaaSAdapter` fails rather than inventing routes. The app never sends customer data or authenticated traffic to a guessed SaaS URL.

The following are **proposed endpoint capabilities**, not existing endpoints:

| Proposed read-only route | Required response |
|---|---|
| `GET /me` | user, tenant membership, role, granted scopes |
| `GET /business/profile` | business identity, profession, city, display name |
| `GET /business/services` | authorized service descriptions |
| `GET /business/channels` | approved website/social URLs and access scope |
| `GET /business/appointments?from=&to=` | bounded authorized appointment summaries |
| `GET /business/analytics?from=&to=` | metric value, units, period, provenance |
| `GET /business/jobs` | bounded job summaries |
| `GET /business/customers` | minimal customer fields; use only when necessary and authorized |
| `GET /knowledge/articles` | published articles with revision and permissions |

Before real integration, obtain the existing OpenAPI contract, staging host, issuer/discovery URL, authorization/token endpoints, mobile client ID, callback URI, PKCE support, audience, signing keys/JWKS, tenant claim semantics, read scopes, user delegation mechanism, pagination, rate limits, revocation/logout and deletion expectations. Do not use an unrestricted service credential. Delegate only the authenticated user's authorized scope. Cache only with explicit TTL/tenant/user keys.

`SaaSAdapter.context(Identity)` is the typed integration boundary. `BusinessContext` contains mode, verified status, business name, profession, city, services and notice. Expand the model only against verified contracts; preserve missing/unknown facts instead of filling them in.

Backend JWT mode validates RS256 signature, expiry, issuer, audience and required identity claims using an operator-provided public key. It does not implement dynamic JWKS rotation or token exchange. The Flutter login is a development token bootstrap, not OAuth. Production PKCE requires authorization in the external user agent, state/nonce, secure callbacks, refresh/revocation behavior and secure token storage. Do not ship the development screen as SaaS login.

Mock mode returns one clearly hypothetical Casablanca carpentry profile; it contains no real appointments, customers or analytics. Both the mobile banner and prompting label it as an example. `SAAS_MODE` currently rejects values other than `mock`. A production-configured JWT server can still have mock SaaS data; it must not be represented as a live business integration.
