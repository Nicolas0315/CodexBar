---
summary: "Makora provider data source: account API token + credits/status balance."
read_when:
  - Adding or tweaking Makora credit balance parsing
  - Updating Makora API token handling
  - Documenting Makora credit semantics
---

# Makora provider

Makora is API-token-only. CodexBar reads `GET https://app.makora.com/api/v1/credits/status`
with a Bearer token and displays the returned prepaid credit balance.

## Data sources

1. **API token**, resolved in this order:
   - `MAKORA_API_TOKEN`, `MAKORA_TOKEN`, or `MAKORA_API_KEY` from the process environment.
   - Settings → Providers → Makora, stored in `~/.codexbar/config.json`.
   - `~/.makora/user`, the credential file written by the `makora login` CLI. Override
     the path with `MAKORA_USER_FILE`.
2. **Credits endpoint**
   - `GET https://app.makora.com/api/v1/credits/status`
   - Request headers: `Authorization: Bearer <token>`, `Accept: application/json`
   - Response fields: `balance`, `currency`, `has_payment_method`,
     `has_default_payment_method`
3. **Account identity** (best effort)
   - `GET https://app.makora.com/api/v1/auth/me` supplies the account email. A failure
     here never hides the balance.

## Usage details

- The primary row shows the prepaid credit balance. Makora reports a balance with no
  spend cap, so the bar only distinguishes present credits (`0%` used) from an exhausted
  balance (`100%` used) and the exact amount lives in the detail line.
- `currency` is normally `Credits`, where 1 credit = $1. Both values are shown verbatim
  (for example `42.50 Credits`); when the field is absent the balance renders as dollars.
- Balances are floored to cents so sub-cent reconcilation noise never overstates credits.
- There is no reset window: Makora credits do not expire on a schedule, so the row has no
  countdown.

## Endpoint notes

Makora's account API is served from the dashboard origin `app.makora.com`. The separate
`be.prod.makora.com` deployment documented by `makora info`'s default `MAKORA_AUTH_URL`
does **not** mount the credits router (it answers `404 Not Found`), while `app.makora.com`
mounts it (it answers `401 Not authenticated`). CodexBar therefore targets
`app.makora.com`.

Authentication is the dashboard's OAuth2 password-flow bearer JWT; the token created at
`https://generate.makora.com/tokens` satisfies it. Makora answers a token whose account it
cannot resolve with `404 {"detail":"User not found"}` rather than `401`, so CodexBar
reports that case as "Makora does not recognize this API token's account" instead of a
generic HTTP error.

The response schema above is taken from the app's own OpenAPI document,
`https://app.makora.com/api/v1/openapi.json` (`CreditsStatusOut`).

## Related files

- `Sources/CodexBarCore/Providers/Makora/`
- `Sources/CodexBar/Providers/Makora/`
- `Tests/CodexBarTests/MakoraUsageFetcherTests.swift`
- `Tests/CodexBarTests/MakoraSettingsReaderTests.swift`
