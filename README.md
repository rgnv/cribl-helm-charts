![Cribl Logo](images/Cribl_Logo_Color_TM.png)

# Cribl Helm Charts

This is a Helm repository for charts published by Cribl, Inc.

We now have a really fast way to deploy an entire distributed Cribl Stream environment to a Kubernetes cluster, using the workergroup and leader Helm charts.

# Prerequisites

Helm version 3 is required to use these charts.

To install Helm on (e.g.) a Mac, using Homebrew:

```
brew install helm
```

Instructions for other operating systems can be found here: https://helm.sh/docs/intro/install/

# Deploying

If you haven't done so already, create a namespace. Our documentation example uses `cribl-stream`.

```
kubectl create namespace cribl-stream
```

Add the Cribl Helm repo.

```
helm repo add cribl https://criblio.github.io/helm-charts/
```

The following example creates a distributed deployment with two auto-scaled worker groups:

- `pcilogs`
- `system-metrics`

In addition, the example:

- Uses an auth token of `ABCDEF01-1234-5678-ABCD-ABCDEF012345`
- Sets an admin password
- Installs our license

For Workers to communicate with the Leader node, both Worker Group deployments reference the Service (`ls-leader-internal`) created by deployment of the Leader Helm chart.

```shell
helm install ls-leader cribl/logstream-leader \
  --set "config.groups={pcilogs,system-metrics}" \
  --set config.token="ABCDEF01-1234-5678-ABCD-ABCDEF012345" \
  --set config.adminPassword="<admin password>" \
  --set config.license="<license key>" \
  -n cribl-stream

helm install ls-wg-pci cribl/logstream-workergroup \
  --set config.host="ls-leader-internal" \
  --set config.tag="pcilogs" \
  --set config.token="ABCDEF01-1234-5678-ABCD-ABCDEF012345" \
  -n cribl-stream

helm install ls-wg-system-metrics cribl/logstream-workergroup \
  --set config.host="ls-leader-internal" \
  --set config.tag="system-metrics" \
  --set config.token="ABCDEF01-1234-5678-ABCD-ABCDEF012345" \
  -n cribl-stream
```

## Running Distributed on a Free License

To run a distributed instance without specifying a license in your install, go into Cribl Stream's user interface and accept the Free license. The Free license allows only one Worker Group.

You can configure the Leader as Distributed, by specifying the `config.groups` option. If you don't specify it, the default configuration is Single Instance mode. You can later manually reconfigure it as Distributed via Cribl Stream's UI.

# Upgrading

Upgrading Cribl Stream to new bits is easy. Update the repo, and then upgrade each chart version. The example below updates to the current version, but you can append `--version X.Y.Z` if you want to [specify a particular version](https://helm.sh/docs/helm/helm_upgrade/).

```
helm repo update
helm upgrade ls-leader cribl/logstream-leader -n cribl-stream
helm upgrade ls-wg-pci cribl/logstream-workergroup -n cribl-stream
helm upgrade ls-wg-system-metrics cribl/logstream-workergroup -n cribl-stream
```

# Deployment Options

These charts support multiple deployment scenarios beyond the default LoadBalancer setup:

## Service Types

- **LoadBalancer** (default): Cloud provider load balancer for external access
- **ClusterIP**: Internal-only access, requires Ingress or Route for external traffic
- **NodePort**: External access via node ports, useful when LoadBalancer is unavailable

## Platform-Specific Examples

### OpenShift Deployment

OpenShift requires specific security contexts and service configurations. See:
- Leader: [examples/openshift-values.yaml](helm-chart-sources/logstream-leader/examples/openshift-values.yaml)
- Worker Group: [examples/openshift-values.yaml](helm-chart-sources/logstream-workergroup/examples/openshift-values.yaml)
- Security Context Constraint: [examples/openshift-scc.yaml](examples/openshift-scc.yaml)

### NodePort Deployment

For clusters without LoadBalancer support or OpenShift restrictions:
- Leader: [examples/nodeport-values.yaml](helm-chart-sources/logstream-leader/examples/nodeport-values.yaml)
- Worker Group: [examples/nodeport-values.yaml](helm-chart-sources/logstream-workergroup/examples/nodeport-values.yaml)

### Kubernetes Gateway API

Modern alternative to Ingress with TCP/UDP routing support:
- Leader: [examples/kubernetes-gateway-api.yaml](helm-chart-sources/logstream-leader/examples/kubernetes-gateway-api.yaml)
- Worker Group: [examples/kubernetes-gateway-api.yaml](helm-chart-sources/logstream-workergroup/examples/kubernetes-gateway-api.yaml)

## Example Files

|File | Purpose | Chart|
|------|---------|-------|
| `openshift-values.yaml` |OpenShift deployment with security contexts| Leader, Worker Group |
| `nodeport-values.yaml` |NodePort service configuration| Leader, Worker Group|
| `kubernetes-gateway-api.yaml` | Gateway API routing | Leader, Worker Group |

## Testing Infrastructure

Local testing environments for development and validation:

- **k3s on PVE**: [docs/testing-local-k3s.md](docs/testing-local-k3s.md) - Lightweight Kubernetes on Proxmox VE
- **kind with OpenShift Security**: [docs/testing-kind-openshift.md](docs/testing-kind-openshift.md) - Kubernetes in Docker with restricted pod security

Automated testing scripts:
- [scripts/test-local-k3s.sh](scripts/test-local-k3s.sh) - k3s cluster testing
- [scripts/test-kind-openshift.sh](scripts/test-kind-openshift.sh) - kind cluster testing with OpenShift-like security

# Contributing

We welcome contributions! If you're interested in developing or contributing to these Helm charts, please see our [CONTRIBUTING.md](CONTRIBUTING.md) for detailed information on:

- Repository structure and development workflow
- Testing and validation procedures
- Coding standards and best practices
- Release process

# Support

Our community supports all items in the Cribl Helm repository – Please join our [Slack Community](https://cribl.io/community/)!
