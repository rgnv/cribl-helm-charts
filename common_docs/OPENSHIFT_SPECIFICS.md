# OpenShift-Specific Info and Errata

This document provides OpenShift-specific information for deploying Cribl Helm charts on OpenShift clusters, including Security Context Constraints (SCC) requirements and distributed mode configuration.

## Security Context Constraints (SCC)

OpenShift uses Security Context Constraints (SCC) to control pod permissions. By default, pods run under the `restricted` SCC, which has specific requirements that differ from standard Kubernetes deployments.

### SCC-Compliant Configuration

To deploy Cribl charts on OpenShift without requiring custom SCCs, use the following security context configuration:

```yaml
podSecurityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

**Key Points:**

1. **Do NOT set specific UIDs** - OpenShift assigns UIDs from the namespace's UID range (see annotation `openshift.io/sa.scc.uid-range`)
2. **Do NOT add capabilities** - The `restricted` SCC does not allow capabilities like `CAP_NET_BIND_SERVICE` or `CAP_SYS_PTRACE`
3. **Use `runAsNonRoot: true`** - Required for `restricted` SCC compliance
4. **Set `seccompProfile.type: RuntimeDefault`** - Required for `restricted` SCC compliance
5. **Set `allowPrivilegeEscalation: false`** - Required for `restricted` SCC compliance

### Namespace UID Range

Each OpenShift namespace has a specific UID range assigned. To view the UID range for a namespace:

```bash
oc get namespace <namespace-name> -o jsonpath='{.metadata.annotations.openshift\.io/sa\.scc\.uid-range}'
```

Example output: `1000660000/10000` (UIDs 1000660000-1000669999)

### Custom SCC (Optional)

If you need capabilities or specific UIDs, you can create a custom SCC. However, this is **not recommended for production** environments.

```yaml
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: cribl-scc
allowPrivilegedContainer: false
allowHostNetwork: false
allowHostDirVolumePlugin: false
allowHostPorts: false
allowHostPID: false
allowHostIPC: false
readOnlyRootFilesystem: false
runAsUser:
  type: MustRunAsRange
  uidRangeMin: 1000
  uidRangeMax: 65535
seLinuxContext:
  type: MustRunAs
fsGroup:
  type: MustRunAs
supplementalGroups:
  type: MustRunAs
requiredDropCapabilities:
  - ALL
defaultAddCapabilities: []
allowedCapabilities:
  - NET_BIND_SERVICE
  - SYS_PTRACE
```

To grant the SCC to a service account:

```bash
oc adm policy add-scc-to-user cribl-scc -z cribl-leader-sa -n <namespace>
```

## Distributed Mode Configuration

Cribl Stream supports distributed mode where workers connect to a leader node. This requires specific configuration in the Helm charts.

### Leader Configuration

The leader must have `config.token` set to enable distributed mode:

```yaml
config:
  criblHome: /tmp/cribl
  token: "your-secure-token-here"
```

**Important:** Without `config.token`, the leader runs in standalone mode (port 9000 only) and does not enable port 4200 for worker connections.

### Worker Group Configuration

Workers must have the **same token** as the leader:

```yaml
config:
  criblHome: /tmp/cribl
  token: "your-secure-token-here"  # Must match leader token
```

### Environment Variables

When `config.token` is set, the following environment variables are automatically configured:

- `CRIBL_DIST_MODE=leader` (for leader) or `worker` (for workers)
- `CRIBL_DIST_MASTER_URL=tcp://<token>@0.0.0.0:4200` (for leader)
- `CRIBL_DIST_LEADER_URL=tcp://<token>@<leader-host>:4200` (for workers)

### Ports

- **Port 9000**: API server (leader and workers)
- **Port 4200**: Distributed worker communication (leader only, enabled when `config.token` is set)

## Resource Requirements

OpenShift clusters, especially development environments like CRC (CodeReady Containers), may have limited resources. Adjust resource limits accordingly:

```yaml
resources:
  limits:
    cpu: 500m
    memory: 1536Mi
  requests:
    cpu: 100m
    memory: 256Mi
```

**Note:** CRC clusters typically have ~10GB memory available. Running both leader and workers may require reducing memory limits to fit within constraints.

## Ingress Configuration

OpenShift supports standard Kubernetes Ingress resources. Use the following configuration:

```yaml
ingress:
  enable: true
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
  hosts:
    - host: cribl.apps.your-openshift-domain.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: cribl-tls
      hosts:
        - cribl.apps.your-openshift-domain.com
```

**Note:** OpenShift Routes are not required. Standard Kubernetes Ingress works with OpenShift's built-in ingress controllers.

## Example Deployment

### Leader Deployment

```yaml
# SCC-compliant configuration
podSecurityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL

# Distributed mode configuration
config:
  criblHome: /tmp/cribl
  token: "your-secure-token-here"

service:
  internalType: ClusterIP
  externalType: ClusterIP

serviceAccount:
  create: true
  name: cribl-leader-sa

persistence:
  enabled: false

resources:
  limits:
    cpu: 500m
    memory: 1536Mi
  requests:
    cpu: 100m
    memory: 256Mi
```

### Worker Group Deployment

```yaml
# SCC-compliant configuration
podSecurityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL

# Distributed mode configuration
config:
  criblHome: /tmp/cribl
  token: "your-secure-token-here"  # Must match leader token

service:
  type: ClusterIP

serviceAccount:
  create: true

autoscaling:
  enabled: false

replicaCount: 1

resources:
  limits:
    cpu: 500m
    memory: 1024Mi
  requests:
    cpu: 100m
    memory: 256Mi
```

## Troubleshooting

### SCC Violations

**Error:** `pods "cribl-leader-xxx" is forbidden: unable to validate against any security context constraint`

**Solution:** Ensure your configuration is SCC-compliant:
- Remove specific `runAsUser`, `runAsGroup`, and `fsGroup` values
- Remove capabilities from `securityContext.capabilities.add`
- Add `runAsNonRoot: true`, `seccompProfile.type: RuntimeDefault`, and `allowPrivilegeEscalation: false`

### Distributed Mode Issues

**Problem:** Workers cannot connect to leader on port 4200

**Solution:** 
1. Verify `config.token` is set on the leader
2. Verify workers have the same `config.token` as the leader
3. Check leader logs for `CriblMaster` initialization on port 4200
4. Verify leader is listening on port 4200: `ss -tlnp | grep 4200`

### Memory Issues

**Problem:** Pods crash with `CrashLoopBackOff` or `OOMKilled`

**Solution:**
1. Increase memory limits (leader typically needs 1.5-2GB)
2. Check node memory allocation: `oc describe node <node-name> | grep -A 5 "Allocated resources:"`
3. Reduce replica count if running multiple workers

### Pod Security Context

**Problem:** Pod fails to start with security context errors

**Solution:** Check the rendered manifest:
```bash
helm template <release-name> <chart-path> -f <values-file> | grep -A 20 "securityContext:"
```

Verify it matches SCC requirements (no specific UIDs, no capabilities, `runAsNonRoot: true`, etc.).

## Testing on CRC (CodeReady Containers)

For local OpenShift testing, use CRC (CodeReady Containers):

1. **Install CRC:** Follow the [CRC installation guide](https://developers.redhat.com/products/codeready-containers)
2. **Configure non-standard ports** (if port 443 is in use):
   ```bash
   crc config set ingress-https-port 8443
   crc config set ingress-http-port 8080
   crc start
   ```
3. **Login:**
   ```bash
   eval $(crc oc-env)
   oc login -u kubeadmin -p <password> https://api.crc.testing:6443
   ```
4. **Create namespace:**
   ```bash
   oc new-project cribl-test
   ```
5. **Deploy charts** using the example configurations above.

**CRC Limitations:**
- Limited memory (~10GB total)
- Single node cluster
- Not suitable for production workloads
- May require reduced resource limits for multiple deployments
