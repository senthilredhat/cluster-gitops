#!/bin/bash
# Script to validate the Helm chart before installation
# Usage: ./validate-chart.sh <cluster-name> [values-file]

set -e

CLUSTER_NAME="${1}"
VALUES_FILE="${2}"
NAMESPACE="clusters"
CHART_DIR="$(dirname $(dirname $(readlink -f $0)))"

if [ -z "$CLUSTER_NAME" ]; then
    echo "Usage: $0 <cluster-name> [values-file]"
    echo ""
    echo "Examples:"
    echo "  $0 prod01"
    echo "  $0 prod01 my-values.yaml"
    echo ""
    exit 1
fi

echo "🔍 Validating Helm chart for cluster: $CLUSTER_NAME"
echo "📂 Chart directory: $CHART_DIR"
echo ""

# Build helm template command
HELM_CMD="helm template $CLUSTER_NAME $CHART_DIR --namespace $NAMESPACE"
if [ -n "$VALUES_FILE" ]; then
    if [ ! -f "$VALUES_FILE" ]; then
        echo "❌ Values file not found: $VALUES_FILE"
        exit 1
    fi
    HELM_CMD="$HELM_CMD -f $VALUES_FILE"
    echo "📄 Using values file: $VALUES_FILE"
else
    HELM_CMD="$HELM_CMD --set cluster.name=$CLUSTER_NAME"
    echo "📄 Using default values with cluster name: $CLUSTER_NAME"
fi

echo ""
echo "📋 Step 1: Linting Helm chart..."
helm lint "$CHART_DIR" >/dev/null 2>&1 && echo "   ✅ Chart lint passed" || (echo "   ❌ Chart lint failed" && exit 1)

echo ""
echo "📋 Step 2: Generating templates..."
$HELM_CMD >/dev/null 2>&1 && echo "   ✅ Template generation successful" || (echo "   ❌ Template generation failed" && exit 1)

echo ""
echo "📋 Step 3: Checking required secrets..."

# Extract cluster name from values if provided
if [ -n "$VALUES_FILE" ]; then
    ACTUAL_CLUSTER_NAME=$(yq eval '.cluster.name' "$VALUES_FILE" 2>/dev/null || echo "$CLUSTER_NAME")
else
    ACTUAL_CLUSTER_NAME="$CLUSTER_NAME"
fi

check_secret() {
    local secret_name=$1
    local secret_desc=$2

    if oc get secret "$secret_name" -n "$NAMESPACE" &>/dev/null; then
        echo "   ✅ $secret_desc exists: $secret_name"
        return 0
    else
        echo "   ❌ $secret_desc missing: $secret_name"
        return 1
    fi
}

MISSING_SECRETS=0

check_secret "pullsecret-cluster-${ACTUAL_CLUSTER_NAME}" "Pull secret" || MISSING_SECRETS=$((MISSING_SECRETS+1))
check_secret "sshkey-cluster-${ACTUAL_CLUSTER_NAME}" "SSH key" || MISSING_SECRETS=$((MISSING_SECRETS+1))
check_secret "infra-cluster-${ACTUAL_CLUSTER_NAME}" "Infra kubeconfig" || MISSING_SECRETS=$((MISSING_SECRETS+1))

if [ $MISSING_SECRETS -gt 0 ]; then
    echo ""
    echo "⚠️  Warning: $MISSING_SECRETS required secret(s) missing!"
    echo ""
    echo "   To create missing secrets, run:"
    echo "   ./scripts/prepare-secrets.sh $ACTUAL_CLUSTER_NAME"
    echo ""
fi

echo ""
echo "📋 Step 4: Checking prerequisites..."

# Check if MCE operator is installed
if oc get crd hostedclusters.hypershift.openshift.io &>/dev/null; then
    echo "   ✅ Multi Cluster Engine (MCE) operator is installed"
else
    echo "   ❌ Multi Cluster Engine (MCE) operator not found"
fi

# Check if MetalLB is available
if oc get namespace metallb-system &>/dev/null; then
    echo "   ✅ MetalLB namespace exists"

    # Check IP pools
    IP_POOLS=$(oc get ipaddresspool -n metallb-system --no-headers 2>/dev/null | wc -l)
    if [ "$IP_POOLS" -gt 0 ]; then
        echo "   ✅ MetalLB has $IP_POOLS IP pool(s) configured"
    else
        echo "   ⚠️  No MetalLB IP pools found"
    fi
else
    echo "   ⚠️  MetalLB namespace not found (LoadBalancer may not work)"
fi

# Check storage class
STORAGE_CLASS=$(yq eval '.etcd.storage.storageClassName' "$VALUES_FILE" 2>/dev/null || echo "lvms-vg1")
if oc get storageclass "$STORAGE_CLASS" &>/dev/null; then
    echo "   ✅ Storage class exists: $STORAGE_CLASS"
else
    echo "   ⚠️  Storage class not found: $STORAGE_CLASS"
fi

echo ""
echo "📋 Step 5: Preview generated resources..."
echo ""

# Show what will be created
$HELM_CMD | grep -E "^(kind:|  name:)" | sed 's/^/   /'

echo ""
echo "✅ Validation complete!"
echo ""

if [ $MISSING_SECRETS -eq 0 ]; then
    echo "🚀 Ready to install:"
    if [ -n "$VALUES_FILE" ]; then
        echo "   helm install $CLUSTER_NAME $CHART_DIR -n $NAMESPACE -f $VALUES_FILE"
    else
        echo "   helm install $CLUSTER_NAME $CHART_DIR -n $NAMESPACE --set cluster.name=$CLUSTER_NAME"
    fi
else
    echo "⚠️  Please create missing secrets before installing"
    echo "   ./scripts/prepare-secrets.sh $ACTUAL_CLUSTER_NAME"
fi

echo ""
