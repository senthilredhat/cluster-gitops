# Hosted Cluster Helm Chart

A Helm chart for deploying OpenShift Hosted Clusters using Multi Cluster Engine (MCE) and OpenShift Virtualization.

## Features

- Deploy hosted OpenShift clusters on KubeVirt infrastructure
- Configurable compute resources (CPU, memory, storage)
- Independent domain names with LoadBalancer ingress (standard ports 80/443)
- Automatic secret name generation based on cluster name
- Support for both single-replica and highly-available configurations
- Customizable networking, storage, and autoscaling settings

## Prerequisites

Before deploying a hosted cluster, ensure you have:

1. **Multi Cluster Engine (MCE)** operator installed on the management cluster
2. **OpenShift Virtualization** operator installed and configured
3. **MetalLB** or another LoadBalancer provider configured with available IP addresses
4. **Storage class** available for persistent volumes (default: `lvms-vg1`)
5. **Required secrets** created in the target namespace

## Required Secrets

Before installing the chart, you must create the following secrets in the namespace where the hosted cluster will be deployed (default: `clusters`):

### 1. Pull Secret

```bash
# Create from your existing pull secret
oc create secret generic pullsecret-cluster-<CLUSTER_NAME> \
  -n clusters \
  --from-file=.dockerconfigjson=/path/to/pull-secret.json \
  --type=kubernetes.io/dockerconfigjson
```

Or copy from an existing cluster:

```bash
oc get secret pullsecret-cluster-demo01 -n clusters -o yaml | \
  sed 's/demo01/<NEW_CLUSTER_NAME>/g' | \
  sed '/resourceVersion:/d' | sed '/uid:/d' | sed '/creationTimestamp:/d' | \
  oc apply -f -
```

### 2. SSH Key

```bash
# Create from your SSH public key
oc create secret generic sshkey-cluster-<CLUSTER_NAME> \
  -n clusters \
  --from-file=id_rsa.pub=/path/to/your/ssh/key.pub
```

Or copy from an existing cluster:

```bash
oc get secret sshkey-cluster-demo01 -n clusters -o yaml | \
  sed 's/demo01/<NEW_CLUSTER_NAME>/g' | \
  sed '/resourceVersion:/d' | sed '/uid:/d' | sed '/creationTimestamp:/d' | \
  oc apply -f -
```

### 3. Infrastructure Kubeconfig

This is the kubeconfig for the cluster where VMs will be created (usually the management cluster itself):

```bash
# Create from current context
oc create secret generic infra-cluster-<CLUSTER_NAME> \
  -n clusters \
  --from-file=kubeconfig=$HOME/.kube/config
```

Or copy from an existing cluster:

```bash
oc get secret infra-cluster-demo01 -n clusters -o yaml | \
  sed 's/demo01/<NEW_CLUSTER_NAME>/g' | \
  sed '/resourceVersion:/d' | sed '/uid:/d' | sed '/creationTimestamp:/d' | \
  oc apply -f -
```

### 4. etcd Encryption Key (Automatically Created)

The chart automatically creates the etcd encryption key secret. If you need to create it manually:

```bash
oc create secret generic <CLUSTER_NAME>-etcd-encryption-key \
  -n clusters \
  --from-literal=key=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 -w 0)
```

## Installation

### Quick Start

1. Create the required secrets (see above)

2. Create a custom values file:

```bash
cat > my-cluster-values.yaml << EOF
cluster:
  name: "cluster01"
  # baseDomain will be auto-generated as: cluster01.skumars.net

nodePool:
  replicas: 3
  compute:
    cores: 8
    memory: 32
EOF
```

3. Install the chart:

```bash
helm install cluster01 ./hostedCluster \
  -n clusters \
  --create-namespace \
  -f my-cluster-values.yaml
```

### Using Helm CLI with Custom Values

```bash
helm install my-cluster ./hostedCluster \
  -n clusters \
  --set cluster.name=my-cluster \
  --set nodePool.replicas=3 \
  --set nodePool.compute.cores=8 \
  --set nodePool.compute.memory=32
```

### Using with ArgoCD/GitOps

Create an ArgoCD Application manifest:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hosted-cluster-prod01
  namespace: openshift-gitops
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo.git
    targetRevision: main
    path: clusters/mocp/day2/hostedCluster
    helm:
      values: |
        cluster:
          name: "prod01"
          rootDomain: "example.com"
        nodePool:
          replicas: 5
          compute:
            cores: 16
            memory: 64
  destination:
    server: https://kubernetes.default.svc
    namespace: clusters
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

## Configuration

### Essential Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `cluster.name` | Name of the hosted cluster | `demo01` | **Yes** |
| `cluster.rootDomain` | Root domain for auto-generated baseDomain | `skumars.net` | No |
| `nodePool.replicas` | Number of worker nodes | `2` | No |
| `nodePool.compute.cores` | CPU cores per node | `4` | No |
| `nodePool.compute.memory` | Memory in Gi per node | `16` | No |

### All Available Parameters

See `values.yaml` for the complete list of configurable parameters.

#### Cluster Configuration

```yaml
cluster:
  name: "my-cluster"                  # Cluster name
  namespace: "clusters"                # Namespace for hosted cluster resources
  baseDomain: ""                       # Custom base domain (optional)
  autoBaseDomain: true                 # Auto-generate baseDomain from name
  rootDomain: "skumars.net"           # Root domain for auto-generation
  baseDomainPassthrough: false         # Use management cluster ingress (not recommended)
  releaseImage: "quay.io/openshift-release-dev/ocp-release:4.20.10-multi"
  fips: false
  olmCatalogPlacement: "management"
  clusterSet: "default"
```

#### Node Pool Configuration

```yaml
nodePool:
  name: ""                            # Auto-generated: <cluster.name>-pool
  replicas: 2                          # Number of worker nodes
  autoRepair: false
  upgradeType: "Replace"
  compute:
    cores: 4                           # CPU cores per node
    memory: 16                         # Memory in Gi per node
  rootVolume:
    type: "Persistent"
    persistent:
      storageClass: "lvms-vg1"
      size: "120Gi"
```

#### Infrastructure Configuration

```yaml
infrastructure:
  namespace: "mocp"                    # Namespace where VMs will be created
  infraKubeConfigSecretName: ""        # Auto-generated if useAutoSecretNames is true
  useAutoSecretNames: true
```

#### Secrets Configuration

```yaml
secrets:
  pullSecretName: ""                   # Auto-generated: pullsecret-cluster-<name>
  sshKeyName: ""                       # Auto-generated: sshkey-cluster-<name>
  useAutoSecretNames: true
  createEtcdEncryptionKey: true        # Automatically create etcd encryption key
```

#### Networking Configuration

```yaml
networking:
  clusterNetwork:
    - cidr: "10.132.0.0/14"
  serviceNetwork:
    - cidr: "172.31.0.0/16"
  networkType: "OVNKubernetes"
```

#### Storage Configuration

```yaml
etcd:
  storage:
    storageClassName: "lvms-vg1"
    size: "8Gi"
```

#### High Availability

```yaml
highAvailability:
  controllerAvailabilityPolicy: "SingleReplica"      # or "HighlyAvailable"
  infrastructureAvailabilityPolicy: "SingleReplica"  # or "HighlyAvailable"
```

## Examples

### Example 1: Small Development Cluster

```yaml
cluster:
  name: "dev01"

nodePool:
  replicas: 1
  compute:
    cores: 2
    memory: 8
  rootVolume:
    persistent:
      size: "60Gi"
```

### Example 2: Production Cluster with High Availability

```yaml
cluster:
  name: "prod01"
  rootDomain: "production.example.com"

nodePool:
  replicas: 5
  compute:
    cores: 16
    memory: 64
  rootVolume:
    persistent:
      size: "500Gi"

highAvailability:
  controllerAvailabilityPolicy: "HighlyAvailable"
  infrastructureAvailabilityPolicy: "HighlyAvailable"
```

### Example 3: Custom Domain and Resources

```yaml
cluster:
  name: "custom01"
  autoBaseDomain: false
  baseDomain: "ocp.mycompany.com"

nodePool:
  replicas: 3
  compute:
    cores: 12
    memory: 48
  rootVolume:
    persistent:
      storageClass: "fast-ssd"
      size: "250Gi"

etcd:
  storage:
    storageClassName: "fast-ssd"
    size: "16Gi"
```

## Post-Installation Steps

### 1. Monitor Cluster Creation

```bash
# Watch cluster status
watch oc get hostedcluster <CLUSTER_NAME> -n clusters

# Check control plane pods
oc get pods -n clusters-<CLUSTER_NAME>

# Check node pool
oc get nodepool <CLUSTER_NAME>-pool -n clusters
```

Wait until the cluster shows `AVAILABLE=True` (typically 10-20 minutes).

### 2. Extract Kubeconfig and Credentials

```bash
# Extract kubeconfig
oc extract secret/<CLUSTER_NAME>-admin-kubeconfig \
  -n clusters \
  --to=- > /tmp/<CLUSTER_NAME>-kubeconfig

# Get kubeadmin password
oc extract secret/<CLUSTER_NAME>-kubeadmin-password \
  -n clusters \
  --to=-
```

### 3. Get LoadBalancer IPs

```bash
# Get API LoadBalancer IP
oc get service kube-apiserver \
  -n clusters-<CLUSTER_NAME> \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}'

# Get Ingress LoadBalancer IP (run after cluster is available)
oc --kubeconfig=/tmp/<CLUSTER_NAME>-kubeconfig \
  get service router-default \
  -n openshift-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}'
```

### 4. Configure DNS

You must configure DNS records for the cluster to be accessible:

#### Option A: Wildcard DNS (Recommended for Production)

```
api.<CLUSTER_NAME>.<ROOT_DOMAIN>          IN A    <API_LOADBALANCER_IP>
*.apps.<CLUSTER_NAME>.<ROOT_DOMAIN>       IN A    <INGRESS_LOADBALANCER_IP>
```

For example, if cluster name is `cluster01` and root domain is `skumars.net`:

```
api.cluster01.skumars.net          IN A    192.168.1.200
*.apps.cluster01.skumars.net       IN A    192.168.1.201
```

#### Option B: dnsmasq (Local Testing)

Add to `/etc/NetworkManager/dnsmasq.d/hosted-clusters.conf`:

```
address=/api.cluster01.skumars.net/192.168.1.200
address=/.apps.cluster01.skumars.net/192.168.1.201
```

Then restart NetworkManager:

```bash
sudo systemctl restart NetworkManager
```

#### Option C: /etc/hosts (Limited)

Add to `/etc/hosts`:

```
192.168.1.200    api.cluster01.skumars.net
192.168.1.201    console-openshift-console.apps.cluster01.skumars.net
192.168.1.201    oauth-openshift.apps.cluster01.skumars.net
```

Note: This requires adding each route individually.

### 5. Access the Cluster

```bash
# Access via kubectl/oc
export KUBECONFIG=/tmp/<CLUSTER_NAME>-kubeconfig
oc get nodes

# Access the console
# https://console-openshift-console.apps.<CLUSTER_NAME>.<ROOT_DOMAIN>
```

## Upgrading a Cluster

To modify cluster resources after deployment:

```bash
# Update values
helm upgrade cluster01 ./hostedCluster \
  -n clusters \
  --set nodePool.replicas=5 \
  --set nodePool.compute.cores=8

# Or with values file
helm upgrade cluster01 ./hostedCluster \
  -n clusters \
  -f updated-values.yaml
```

## Uninstalling

```bash
# Delete the Helm release
helm uninstall <CLUSTER_NAME> -n clusters

# This will delete:
# - HostedCluster resource
# - NodePool resource
# - etcd encryption key secret (if created by chart)

# It will NOT delete:
# - Pull secret
# - SSH key
# - Infra kubeconfig secret
# (These can be reused for other clusters)
```

## Troubleshooting

### Cluster Stuck in Pending

```bash
# Check hosted cluster status
oc describe hostedcluster <CLUSTER_NAME> -n clusters

# Check control plane operator logs
oc logs -n clusters-<CLUSTER_NAME> -l app=control-plane-operator --tail=50

# Verify all secrets exist
oc get secret -n clusters | grep <CLUSTER_NAME>
```

### No LoadBalancer IP Assigned

```bash
# Check MetalLB IP pool
oc get ipaddresspool -n metallb-system

# Ensure sufficient IPs are available
oc get ipaddresspool loadbalancer-pool -n metallb-system -o yaml
```

### Ingress Using NodePort Instead of LoadBalancer

If the cluster's ingress is using NodePort, patch it:

```bash
oc --kubeconfig=/tmp/<CLUSTER_NAME>-kubeconfig \
  patch ingresscontroller default \
  -n openshift-ingress-operator \
  --type=merge \
  -p '{"spec":{"endpointPublishingStrategy":{"type":"LoadBalancerService"}}}'
```

### DNS Not Resolving

```bash
# Test DNS resolution
nslookup api.<CLUSTER_NAME>.<ROOT_DOMAIN>
nslookup console-openshift-console.apps.<CLUSTER_NAME>.<ROOT_DOMAIN>

# Check /etc/resolv.conf
cat /etc/resolv.conf
```

## Architecture

This Helm chart creates:

1. **HostedCluster** - Defines the hosted OpenShift cluster
   - Control plane runs as pods in the management cluster
   - Configured with LoadBalancer for API server
   - Independent domain (not nested under management cluster)

2. **NodePool** - Defines worker nodes
   - Worker nodes run as KubeVirt VirtualMachines
   - Configurable CPU, memory, and storage
   - Auto-scaling support

3. **Secrets**
   - etcd encryption key (auto-generated)
   - Pull secret (must be pre-created)
   - SSH key (must be pre-created)
   - Infrastructure kubeconfig (must be pre-created)

## Key Differences from Default MCE Deployment

This chart configures hosted clusters with:

- ✅ **Independent domains** (`apps.cluster01.skumars.net` instead of `apps.cluster01.apps.mocp.skumars.net`)
- ✅ **Standard ports** (80/443 instead of NodePort random ports like 32128)
- ✅ **LoadBalancer ingress** (instead of NodePortService)
- ✅ **baseDomainPassthrough: false** (independent routing, not through management cluster)

## Contributing

To modify this chart:

1. Update `values.yaml` for new configuration options
2. Update templates as needed
3. Update this README with new parameters
4. Test with `helm template` before deploying:

```bash
helm template test-cluster ./hostedCluster \
  --set cluster.name=test \
  --debug
```

## License

Copyright © 2026 Platform Team
