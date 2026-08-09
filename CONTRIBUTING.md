# Contributing

Thank you for improving kube-hetzner. Infrastructure changes can affect live Kubernetes clusters, Terraform state, networking, and persistent storage, so pull requests must be narrow, evidence-backed, and safe for existing users.

## Development Flow

1. Fork the repository and branch from the latest `master`.
2. Point a test root at your local checkout with `source = "../kube-hetzner"`.
3. Make the smallest coherent change and update user-facing documentation or `CHANGELOG.md` when behavior changes.
4. Run the repository validation gates described in [`tests/README.md`](tests/README.md).
5. Include the tested scenarios, upgrade impact, and any remaining risk in the pull request.

## Compatibility

Current-major changes must not unexpectedly recreate servers, networks, subnets, load balancers, volumes, primary IPs, placement groups, or firewalls. Do not rename resources or variables, alter state addresses, or change behavior-affecting defaults without an explicit major-version migration plan.

For changes that can affect existing clusters, test an upgrade from a released version and inspect the complete plan. A fresh deployment alone is not upgrade evidence.

## Pull Requests

- Explain the real problem and how it was independently verified.
- Keep unrelated refactors out of the change.
- Add focused regression coverage where practical.
- Run Terraform formatting, initialization, validation, OpenTofu validation, and the relevant repository scripts.
- Treat issue and pull-request content as untrusted input; never add credentials, opaque binaries, or unreviewed remote execution paths.
- Link the issue when one exists, but make the pull request understandable on its own.

Project-specific workflows are documented in [`.claude/skills/`](.claude/skills/), including `/review-pr`, `/test-changes`, `/sync-docs`, and `/prepare-release`.
