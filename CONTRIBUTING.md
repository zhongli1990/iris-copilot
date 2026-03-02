# Contributing

Thanks for contributing to IRIS Copilot.

## Contributor Licence Agreement (CLA)

By submitting a contribution (code, documentation, tests, configuration,
or any other materials) to this repository, you confirm that:

1. **Right to contribute:** You have the legal right to make the
   contribution, and it does not infringe any third-party intellectual
   property rights, including patents, copyrights, or trade secrets.

2. **Irrevocable licence grant:** You grant Lightweight Integration
   Limited a perpetual, worldwide, irrevocable, royalty-free,
   non-exclusive licence to use, reproduce, modify, adapt, publish,
   translate, distribute, sublicense, and otherwise exploit your
   contribution — including under commercial or proprietary terms —
   as part of the IRIS Copilot Software or any successor project.

3. **Relicensing consent:** You acknowledge and agree that Lightweight
   Integration Limited may relicense the Software, including your
   contribution, under any licence terms it chooses, including the
   IRIS Copilot Community License v1.0 (`LICENSE`) and the Enterprise
   Commercial Licence (`LICENSE-ENTERPRISE.md`).

4. **No compensation:** You are not entitled to any payment, royalty,
   or other compensation for your contribution, unless separately
   agreed in writing with Lightweight Integration Limited.

5. **Employer consent:** If your contribution is made in the course of
   your employment, you confirm that your employer has consented to
   the contribution on these terms, or that you own the intellectual
   property in the contribution independently of your employer.

This CLA is required so the project can remain open to community
contributors while also supporting commercial enterprise licensing.
If you do not agree to these terms, please do not submit contributions.

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
