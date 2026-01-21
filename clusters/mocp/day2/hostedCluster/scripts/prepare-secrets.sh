#!/bin/bash
# Script to prepare required secrets for a new hosted cluster
# Usage: ./prepare-secrets.sh <cluster-name> [source-cluster]

set -e

CLUSTER_NAME="${1}"
SOURCE_CLUSTER="${2:-demo01}"
NAMESPACE="clusters"

if [ -z "$CLUSTER_NAME" ]; then
    echo "Usage: $0 <cluster-name> [source-cluster]"
    echo ""
    echo "Examples:"
    echo "  $0 prod01              # Copy secrets from demo01 (default)"
    echo "  $0 prod01 dev01        # Copy secrets from dev01"
    echo ""
    exit 1
fi

echo "🔐 Preparing secrets for hosted cluster: $CLUSTER_NAME"
echo "📋 Source cluster for copying secrets: $SOURCE_CLUSTER"
echo "📦 Target namespace: $NAMESPACE"
echo ""

# Check if namespace exists
if ! oc get namespace "$NAMESPACE" &>/dev/null; then
    echo "❌ Namespace '$NAMESPACE' does not exist!"
    echo "   Create it with: oc create namespace $NAMESPACE"
    exit 1
fi

# Function to copy secret
copy_secret() {
    local secret_type=$1
    local source_secret="${secret_type}-cluster-${SOURCE_CLUSTER}"
    local target_secret="${secret_type}-cluster-${CLUSTER_NAME}"

    echo "📄 Copying $secret_type secret..."

    if ! oc get secret "$source_secret" -n "$NAMESPACE" &>/dev/null; then
        echo "   ❌ Source secret '$source_secret' not found in namespace '$NAMESPACE'"
        return 1
    fi

    if oc get secret "$target_secret" -n "$NAMESPACE" &>/dev/null; then
        echo "   ⚠️  Secret '$target_secret' already exists, skipping..."
        return 0
    fi

    oc get secret "$source_secret" -n "$NAMESPACE" -o yaml | \
      sed "s/${SOURCE_CLUSTER}/${CLUSTER_NAME}/g" | \
      sed '/resourceVersion:/d' | \
      sed '/uid:/d' | \
      sed '/creationTimestamp:/d' | \
      oc apply -f - >/dev/null

    echo "   ✅ Created: $target_secret"
}

# Copy pull secret
copy_secret "pullsecret"

# Copy SSH key
copy_secret "sshkey"

# Copy infra kubeconfig
copy_secret "infra"

# Create etcd encryption key
echo "📄 Creating etcd encryption key..."
ETCD_SECRET="${CLUSTER_NAME}-etcd-encryption-key"

if oc get secret "$ETCD_SECRET" -n "$NAMESPACE" &>/dev/null; then
    echo "   ⚠️  Secret '$ETCD_SECRET' already exists, skipping..."
else
    oc create secret generic "$ETCD_SECRET" \
      -n "$NAMESPACE" \
      --from-literal=key=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 -w 0) \
      >/dev/null
    echo "   ✅ Created: $ETCD_SECRET"
fi

echo ""
echo "✅ All secrets prepared successfully!"
echo ""
echo "📋 Verify secrets:"
echo "   oc get secret -n $NAMESPACE | grep $CLUSTER_NAME"
echo ""
echo "🚀 Next steps:"
echo "   1. Review/edit your values file"
echo "   2. Install the cluster with:"
echo "      helm install $CLUSTER_NAME ./hostedCluster -n $NAMESPACE -f your-values.yaml"
echo ""
