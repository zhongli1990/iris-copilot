# Contributing

Thanks for contributing to IRIS Copilot.

## Dual-license contribution terms

By submitting a contribution (code, documentation, tests, or other materials),
you agree that your contribution may be distributed under:

1. Apache-2.0 (`LICENSE`)
2. Lightweight Integration Limited commercial enterprise license (`LICENSE-ENTERPRISE.md`)

This is required so the project can remain open to community contributors while
also supporting commercial enterprise licensing.

## Developer setup

1. IRIS classes:
   - Follow `docs/DEPLOYMENT-GUIDE.md`
2. Bridge:
   - `cd bridge`
   - `npm install`
   - `npm run build`
3. E2E sample checks:
   - `npm run e2e:sample`

## Coding expectations

- Keep behavior generic and namespace-agnostic by default.
- Avoid hardcoded customer/site assumptions in runtime paths.
- Add tests or validation steps for new capabilities.
