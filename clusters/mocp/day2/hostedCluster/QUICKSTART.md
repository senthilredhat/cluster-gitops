# Quick Start Guide

Get a hosted cluster running in 5 minutes!

## Prerequisites Check

```bash
# Verify MCE is installed
oc get crd hostedclusters.hypershift.openshift.io

# Verify MetalLB has IPs available
oc get ipaddresspool -n metallb-system

# Verify storage class exists
oc get storageclass lvms-vg1
```

## Step 1: Prepare Secrets

```bash
# Navigate to the chart directory
cd /home/sekumar/cluster01/cluster-gitops/clusters/mocp/day2/hostedCluster

# Prepare secrets for your new cluster (copies from demo01)
./scripts/prepare-secrets.sh prod01

# Or copy from a different source cluster
./scripts/prepare-secrets.sh prod01 dev01
```

## Step 2: Create Your Values File

Choose one:

### Option A: Use an example template

```bash
# Copy and edit an example
cp examples/dev-cluster.yaml my-cluster.yaml

# Edit the values
vi my-cluster.yaml
```

### Option B: Create minimal values file

```bash
cat > my-cluster.yaml << EOF
cluster:
  name: "prod01"

nodePool:
  replicas: 3
  compute:
    cores: 8
    memory: 32
EOF
```

### Option C: Use default values with CLI overrides

Skip creating a file and use `--set` flags (see Step 4).

## Step 3: Validate Configuration

```bash
# Validate before installing
./scripts/validate-chart.sh prod01 my-cluster.yaml

# Or without values file
./scripts/validate-chart.sh prod01
```

## Step 4: Install the Cluster

```bash
# With values file
helm install prod01 . -n clusters -f my-cluster.yaml

# Or with CLI parameters
helm install prod01 . -n clusters \
  --set cluster.name=prod01 \
  --set nodePool.replicas=3 \
  --set nodePool.compute.cores=8 \
  --set nodePool.compute.memory=32
```

## Step 5: Monitor Deployment

```bash
# Watch cluster status (wait for AVAILABLE=True)
watch oc get hostedcluster prod01 -n clusters

# Check control plane pods
oc get pods -n clusters-prod01

# Check node pool
oc get nodepool prod01-pool -n clusters
```

Cluster creation typically takes 10-20 minutes.

## Step 6: Extract Credentials

Once AVAILABLE=True:

```bash
# Extract kubeconfig
oc extract secret/prod01-admin-kubeconfig -n clusters --to=- > /tmp/prod01-kubeconfig

# Get kubeadmin password
oc extract secret/prod01-kubeadmin-password -n clusters --to=-
```

## Step 7: Get LoadBalancer IPs

```bash
# Get API LoadBalancer IP
oc get service kube-apiserver -n clusters-prod01 \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}'

# Get Ingress LoadBalancer IP
oc --kubeconfig=/tmp/prod01-kubeconfig get service router-default \
  -n openshift-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}'
```

## Step 8: Configure DNS

Add these DNS records (replace IPs with values from Step 7):

```
api.prod01.skumars.net          IN A    <API_LOADBALANCER_IP>
*.apps.prod01.skumars.net       IN A    <INGRESS_LOADBALANCER_IP>
```

For local testing with dnsmasq:

```bash
# Add to /etc/NetworkManager/dnsmasq.d/hosted-clusters.conf
sudo tee -a /etc/NetworkManager/dnsmasq.d/hosted-clusters.conf << EOF
address=/api.prod01.skumars.net/<API_IP>
address=/.apps.prod01.skumars.net/<INGRESS_IP>
EOF

# Restart NetworkManager
sudo systemctl restart NetworkManager
```

## Step 9: Access the Cluster

```bash
# Via CLI
export KUBECONFIG=/tmp/prod01-kubeconfig
oc get nodes

# Via Console
# Open: https://console-openshift-console.apps.prod01.skumars.net
# User: kubeadmin
# Password: (from Step 6)
```

## Common Commands

```bash
# List all hosted clusters
oc get hostedclusters -n clusters

# Get cluster status
oc get hostedcluster prod01 -n clusters -o yaml

# Scale node pool
helm upgrade prod01 . -n clusters \
  --reuse-values \
  --set nodePool.replicas=5

# Delete cluster
helm uninstall prod01 -n clusters
```

## Troubleshooting

### Cluster stuck in Pending

```bash
# Check events
oc describe hostedcluster prod01 -n clusters

# Check operator logs
oc logs -n clusters-prod01 -l app=control-plane-operator --tail=50
```

### Secrets not found

```bash
# Verify all secrets exist
oc get secret -n clusters | grep prod01

# Re-run secret preparation
./scripts/prepare-secrets.sh prod01
```

### No LoadBalancer IP

```bash
# Check MetalLB
oc get ipaddresspool -n metallb-system -o yaml

# Check services
oc get svc -n clusters-prod01
```

## Need More Help?

- See [README.md](README.md) for detailed documentation
- Check [examples/](examples/) for more configuration examples
- Review [values.yaml](values.yaml) for all available options
