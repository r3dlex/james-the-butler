# Security Model Specification

For the full platform specification, see [platform.md](platform.md) §6, §4.3, §22.4.

## Purpose

This document defines the authentication, authorization, and transport security model for the James the Butler platform across all clients: web, desktop, mobile, Office add-ins, and Chrome extension.

## Authentication

### OAuth 2.0 Providers

| Provider  | Scope                          |
|-----------|--------------------------------|
| Google    | OpenID Connect, Gmail, Calendar|
| Microsoft | OpenID Connect, Office Graph   |
| GitHub    | User profile, repo access      |

### Multi-Factor Authentication

- **Required**: MFA is mandatory for all accounts. No MFA-less login path exists.
- **TOTP**: Time-based One-Time Password (RFC 6238). Supported by all standard authenticator apps.
- **WebAuthn**: FIDO2 hardware keys and platform authenticators (Touch ID, Windows Hello).
- **SMS**: Not supported. SMS-based MFA is explicitly excluded due to SIM-swap risk.

### Provider OAuth PKCE (LLM Credentials)

Used to connect third-party LLM provider accounts (e.g. OpenAI, OpenAI Codex) to James without exposing API keys in the browser.

1. Frontend calls `POST /api/providers/oauth/start` with the provider type.
2. Backend generates a PKCE verifier/challenge pair and a random state key; stores both in ETS with a 10-minute TTL.
3. Backend returns `auth_url` (containing `code_challenge=…&state=…`) and `state_key`.
4. Frontend opens `auth_url` in a popup window (`600×700px`).
5. User authorises in the popup; the provider redirects to `/api/providers/oauth/callback?code=…&state=…`.
6. Backend verifies the state key, exchanges the code for tokens using the PKCE verifier, and persists the resulting `ProviderConfig` (access token encrypted at rest). Marks the state as `:completed`.
7. Popup auto-closes after displaying a success page.
8. Frontend polls `GET /api/providers/oauth/status/:state_key` (every 3 s, up to 5 min) until it receives `{"status": "completed"}`, then adds the new provider to the UI.

**Security properties**
- PKCE prevents authorization code interception attacks (the verifier never leaves the server).
- State key prevents CSRF on the callback endpoint.
- Tokens are never exposed to the browser; only the resulting `ProviderConfig` (with masked key) is returned to the frontend.
- State entries auto-expire after 10 minutes to prevent abandoned flow accumulation.

### Device Code Flow

Used by Office add-ins ([office-addins.md](office-addins.md)) and Chrome extension ([chrome-extension.md](chrome-extension.md)) where browser-based OAuth redirects are impractical.

1. Client requests a device code from `/auth/device`
2. User visits the verification URL and enters the code in a browser
3. Client polls `/auth/device/token` until the user completes authentication
4. On success, client receives access + refresh token pair
5. One-time per installation; refresh tokens persist

## Token Management

### JWT

| Token Type    | Lifetime | Storage                                      |
|---------------|----------|----------------------------------------------|
| Access token  | 15 min   | Memory (web), Keychain/Keystore (mobile)     |
| Refresh token | 7 days   | HttpOnly cookie (web), secure enclave (mobile)|

- **Rotation**: Refresh tokens rotate on every use. Previous refresh token is invalidated immediately.
- **Revocation**: Logout invalidates all tokens for the session. Admin can revoke all tokens for a user.

### Mobile Credentials

- Access and refresh tokens stored in the device secure enclave (iOS Keychain / Android Keystore)
- QR binding tokens: 5-minute expiry, single-use, signed by the backend
- See [flutter.md](flutter.md) for host binding flow details

## Transport Security

### Inter-Host Communication

- **mTLS**: All host-to-host communication uses mutual TLS with certificate pinning
- **Certificate rotation**: Automated via short-lived certificates (24-hour validity)
- **No plaintext**: HTTP is never accepted; all endpoints enforce HTTPS

### API Security

| Rule                       | Detail                                              |
|----------------------------|-----------------------------------------------------|
| Authentication required    | All endpoints require a valid JWT except `/health`  |
| CORS                       | Origin whitelist configured per deployment           |
| Rate limiting              | Per-user, per-endpoint. Defaults: 60 req/min API, 10 req/min auth |
| Request size               | 10 MB max body size. File uploads via presigned URLs |
| Input validation           | All inputs validated and sanitized at the API boundary |

### WebSocket Security

- WebSocket connections require a valid JWT in the initial handshake
- Tokens are validated on connect and periodically re-verified during long-lived connections
- Channel authorization is per-session: users can only join channels for their own sessions

## Authorization

- Role-based access: `owner`, `admin`, `user` (single-tenant, self-hosted)
- Session isolation: Users can only access their own sessions and data
- Host access: Controlled via host binding (mobile QR) or direct authentication (web/desktop)

## Key Constraints

- No secrets in client-side code or URL parameters
- All cryptographic operations use platform-native libraries (Erlang `:crypto`, Web Crypto API, iOS/Android platform crypto)
- Audit log for all authentication events (login, logout, token refresh, failed attempts)
- Failed login attempts trigger progressive delays (1s, 2s, 4s, ..., max 60s)
