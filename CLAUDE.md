# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AZERTY Snacks is a Dutch-language Progressive Web App for employee snack ordering, built with Vercel serverless functions, Vercel KV (Redis), and vanilla JavaScript. No build step—files deploy directly to Vercel.

## Commands

```bash
# Deploy to production
cd C:/Users/rklin/testclaud/snack-deploy && npx vercel --prod --yes

# Install dependencies (only @vercel/kv)
npm install
```

There are no build, lint, or test commands. The project has no framework, bundler, or test suite.

## Architecture

### Frontend (3 HTML pages, all CSS/JS inline)

- **`index.html`** — Login gate. Password auth (hardcoded: `azerty`) + optional Microsoft SSO via MSAL 2.38.3 redirect flow. Sets `snack_auth` in sessionStorage. All other pages redirect here if not authenticated.
- **`snack-order.html`** — Customer ordering page. Loads menu from `/api/menu`, dates from `/api/dates`, submits orders to `/api/orders`. Has shopping cart, category filters, chat assistant (Anthropic API), QR payment overlay, and "Bestellingen overzicht" section. Supports light/dark mode.
- **`snack-admin.html`** — Admin dashboard. Requires admin token (Bearer auth). Manages dates (open/close/send), views all orders, edits menu with opslag (markup), configures payment QR/link, SSO settings, and chat API key.

### API Endpoints (`api/` directory, Vercel serverless)

All endpoints use `@vercel/kv` for storage. Admin endpoints require `Authorization: Bearer {ADMIN_TOKEN}` header.

| Endpoint | Public | Admin | Purpose |
|---|---|---|---|
| `GET /api/menu` | Menu + opslag | — | Fetch menu items and pricing |
| `POST /api/menu` | — | Save menu | Update menu/opslag |
| `GET /api/orders?date=DD-MM-YYYY` | Orders for date | — | Fetch orders by date |
| `GET /api/orders?all=1` | — | All orders | Fetch all orders (needs auth) |
| `POST /api/orders` | Save order | — | Submit new order |
| `DELETE /api/orders?date=...` | — | Delete orders | Delete by date or order ID |
| `GET /api/dates` | Open + sent dates | — | Which dates accept orders |
| `POST /api/dates` | — | Manage dates | Open/send/unsend dates |
| `GET /api/settings?key=qr` | QR + payment link | — | Payment configuration |
| `GET /api/settings?key=sso` | SSO config | — | SSO settings for login |
| `POST /api/settings` | — | Save settings | QR, payment link, SSO, API key |

### KV Storage Keys

- **Orders**: `orders:DD-MM-YYYY` (array per date), `order_dates` (date index)
- **Dates**: `open_dates`, `sent_dates` (arrays)
- **Menu**: `snack_menu`, `snack_opslag`, `snack_opslag_mode`, `snack_menu_updated_at`
- **Settings**: `payment_qr`, `payment_link`, `snack_api_key`, `sso_*` keys

### Date Format

All dates use `DD-MM-YYYY` format (Dutch locale) throughout the system.

## Environment Variables (Vercel)

- `ADMIN_TOKEN` — Secret for admin API auth (current value: `0011_55_88`)
- Vercel KV credentials are auto-injected by Vercel

## SSO Configuration

Microsoft Azure AD SSO uses MSAL 2.38.3 with redirect flow. Config stored in KV:
- Client ID: `05e6c5c8-3753-4fe4-aa72-3f42b96a9002`
- Tenant ID: `5893fe0d-2f85-410e-bd81-f0b47b88ac6a`
- Allowed domain: `rklinkholding.nl`

## Key Patterns

- **Dual storage for orders**: Orders save to both server (`/api/orders`) and localStorage as fallback. The client merges both sources by deduplicating on `order.id`.
- **Admin auth pattern**: Admin pages store token in localStorage (`admin_token`), send as `Authorization: Bearer` header via `apiCall()` helper.
- **Theme**: Default is dark mode. `html.light` class enables light mode. Toggle persists to localStorage.
- **All CSS/JS is inline**: Each HTML file contains all its styles and scripts. No external CSS or JS bundles.
- **ES5-compatible API code**: Serverless functions use `var`, `.then()` chains, and `module.exports` (CommonJS) for Node.js compatibility.
- **PWA**: `sw.js` caches static assets, serves offline fallback. `manifest.json` enables homescreen install.

## Vercel Project

- Project: `snack-bestelsysteem`
- URL: `https://snack-bestelsysteem.vercel.app`
- GitHub: `https://github.com/KlinkRichard/snack-bestelsysteem.git`
