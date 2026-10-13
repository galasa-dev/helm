# AGENTS.md

## Repository Overview

This repository maintains official Helm charts for deploying the **Galasa** test automation service on Kubernetes.

### Key Charts
- [`charts/ecosystem`](charts/ecosystem): Complete Galasa Ecosystem chart deploying:
  - **API Server** (REST API)
  - **Web UI** (Management web interface)
  - **Engine Controller** (Test pod lifecycle management)
  - **Dex** (OpenID Connect / OAuth authentication)
  - **etcd** (CPS, Credentials, DSS store)
  - **CouchDB** (Test run records and persistent storage)
  - **Resource Monitor** & **Custom Resource Monitor** (Cluster resource tracking and cleanup)
  - **Metrics** (System metrics collection)
  - Optional: Istio mTLS integration, Gateway API / Ingress routing, Kafka integration, Log4j2 customization
- [`charts/cert-installer`](charts/cert-installer): Helper chart for cert-manager TLS certificate issuers (production and staging) and certificate resources.

### Target Environment
- **Kubernetes Version**: `>= 1.28.0`
- **Helm Version**: Helm 3+
- **Container Registry**: `ghcr.io/galasa-dev` (primary registry for Galasa images)

## Directory Structure

```
.
├── charts/
│   ├── ecosystem/                # Galasa Ecosystem Helm chart
│   │   ├── Chart.yaml            # Chart metadata & chart version
│   │   ├── values.yaml           # Default values and configuration options
│   │   ├── rbac.yaml             # Cluster RBAC definitions
│   │   ├── rbac-admin.yaml       # Admin RBAC definitions
│   │   └── templates/            # Kubernetes resource templates
│   │       ├── _helpers.tpl      # Reusable template helpers
│   │       ├── gateway-api/      # Gateway API routes (HTTPRoute, Gateway)
│   │       ├── ingress/          # Ingress resources (api, dex, webui)
│   │       ├── istio/            # Istio PeerAuthentication policies
│   │       └── *.yaml            # Deployments, StatefulSets, Services, ConfigMaps, Jobs
│   └── cert-installer/           # TLS certificate issuer chart
├── .github/
│   ├── workflows/
│   │   ├── ecosystem-chart-pr-test.yaml  # PR validation workflow (Kind + Istio + Helm test)
│   │   ├── build.yaml                    # Triggers automation repo build on main branch push
│   │   └── release.yaml                  # Chart release workflow using chart-releaser
│   ├── ecosystem-chart-pr-test-values.yaml # Test values used in CI
│   └── pull_request_template.md          # PR description template
├── .pre-commit-config.yaml       # IBM detect-secrets baseline check
├── .secrets.baseline             # Secret scanner baseline file
├── set-version.sh                # Version bump utility script
├── rotate-encryption-keys.sh     # Encryption key rotation utility script
├── CONTRIBUTING.md               # Contribution rules and DCO guidance
└── README.md                     # User documentation
```

## Essential Commands & Validation

Always run validation checks before completing tasks involving chart modifications.

### Linting Charts
```bash
helm lint charts/ecosystem
```

### Template Rendering Checks
Validate that the templates render without syntax errors:
```bash
# Render ecosystem chart using CI test values
helm template test charts/ecosystem -f .github/ecosystem-chart-pr-test-values.yaml > /dev/null

# Render default values
helm template test charts/ecosystem > /dev/null
```

### Script Execution
- **Version bump**:
  ```bash
  ./set-version.sh -v <new-version>
  ```
  Updates `version` in [`charts/ecosystem/Chart.yaml`](charts/ecosystem/Chart.yaml) and `galasaVersion` in [`charts/ecosystem/values.yaml`](charts/ecosystem/values.yaml).

- **Encryption key rotation** (operational utility):
  ```bash
  ./rotate-encryption-keys.sh --release-name <release-name> [-n <namespace>] [-b <bootstrap-url>]
  ```
  Requires `kubectl` (v1.30.3+), `openssl` (3.3.2+), and `galasactl` (0.38.0+).

## Code & Contribution Guidelines

### Commit Standards
- **Developer Certificate of Origin (DCO)**: Every commit MUST be signed off with `-s` (`Signed-off-by: Name <email>`).
- **GPG Signing**: Human contributors use `-S` to sign commits with GPG. When agents generate commits, ensure DCO signoff is present.`
- **Conventional Commits**: Use [Conventional Commits](https://www.conventionalcommits.org): `type(scope)!: description` (scope and `!` are optional; `!` marks a breaking change).
  - Example: `feat(ingress): add support for custom annotations`

### Secret Safety
- Secret detection is enforced via IBM `detect-secrets` using [`.secrets.baseline`](.secrets.baseline).
- NEVER hardcode secrets, passwords, tokens, or encryption keys in templates, documentation, or values files.
- Use Kubernetes Secrets or placeholders (e.g., `admin@example.com` for non-sensitive test values).

### Helm Templating Practices
- **Whitespace & Indentation**: YAML indentation is critical. Use standard Helm whitespace trimming (`{{-` and `-}}`) carefully to prevent malformed YAML.
- **Helpers**: Reusable naming logic and URL calculations should use helper functions in [`charts/ecosystem/templates/_helpers.tpl`](charts/ecosystem/templates/_helpers.tpl).
- **Default Values**: Ensure new configurable properties in [`charts/ecosystem/values.yaml`](charts/ecosystem/values.yaml) have clear comments and safe defaults suitable for lightly loaded environments.
- **Dual Networking Support**: When touching routing or external access, consider both Ingress (`ingress.enabled`) and Gateway API (`gatewayApi.enabled`) paths.
- **Image References**: Use `ghcr.io/galasa-dev` as the container image registry.

## CI/CD & Automated Testing Workflow

- **PR Validation (`ecosystem-chart-pr-test.yaml`)**:
  - Triggers on PR changes under `charts/ecosystem/**`.
  - Provisions a Kind cluster, installs Istio + Gateway API CRDs, installs the ecosystem chart with [`.github/ecosystem-chart-pr-test-values.yaml`](.github/ecosystem-chart-pr-test-values.yaml), and runs `helm test galasa`.
- **Main Branch Build (`build.yaml`)**:
  - Triggers the centralized Helm build workflow in `galasa-dev/automation`.
- **Releases (`release.yaml`)**:
  - Triggered on pushes to `prerelease` or `release` branches.
  - Packages and releases charts using Helm `chart-releaser-action`.

## PR Template Structure

When preparing pull requests, structure the description according to [`.github/pull_request_template.md`](.github/pull_request_template.md)
