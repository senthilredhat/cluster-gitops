# Claude Code Configuration

## User Information

- **Name**: sekumar
- **Role**: OpenShift cluster administrator
- **Focus Area**: Day 2 operations and GitOps-based cluster configuration
- **Cluster**: cluster01 (apps.co1.skumars.net)
- **Repository**: https://github.com/senthilredhat/cluster-gitops.git

## Technical Preferences

### GitOps Workflow
- All cluster configurations managed through GitOps using ArgoCD
- ApplicationSet pattern for automatic discovery of new operators/services
- Changes must be committed to git and pushed before validation
- Always validate deployments on the cluster after git push

### Operator Deployment Pattern
Follow this consistent structure for all operator deployments:
```
operator-name/
  ├── 00-namespace.yaml      (sync-wave: "0")
  ├── 01-operatorgroup.yaml  (sync-wave: "1")
  ├── 02-subscription.yaml   (sync-wave: "2")
  └── 03-<custom-resource>.yaml (sync-wave: "10" or higher)
```

### ArgoCD Sync Configuration
- Use sync-wave annotations to control resource creation order
- Namespace: wave 0
- OperatorGroup: wave 1
- Subscription: wave 2
- Custom Resources: wave 10+ (allow time for CRD registration)
- Add `argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true` for CRs that depend on operator CRDs

### Storage
- Default storage class: `lvms-vg1`
- Use both RWO and RWX storage class: `lvms-vg1`

### Security & Safety
- **IMPORTANT**: Always ask before running destructive operations
- Do not delete ArgoCD ApplicationSets without explicit permission
- Do not force-push to git
- Do not skip git hooks or verification steps
- Prefer creating new commits over amending existing ones

## Current Cluster State

### Infrastructure
- **Cluster Type**: Single-node OpenShift cluster (SNO)
- **Node Name**: cluster01
- **Platform**: Virtual machine
- **Node Access**: `ssh core@co1.skumars.net`
- **Console**: https://console-openshift-console.apps.co1.skumars.net
- **Total Memory**: 62.7 GiB

### Storage Configuration
- **Root Disk**: /dev/vda (200 GB) - Container images and OS
  - Filesystem: XFS
  - Mount: /sysroot
  - Container storage: /var/lib/containers/storage
- **LVM Volume Group**: vg1 (400 GB total)
  - Physical Volumes: /dev/vdc (200GB), /dev/vde (200GB)
  - Used for LVMS persistent volumes
- **Storage Class**: lvms-vg1 (for both RWO and RWX)

### Deployed Operators (as of 2026-04-07)
- OpenShift GitOps (ArgoCD) - Day 1
- OpenShift Virtualization
- nmstate-operator (network configuration)
- Red Hat Developer Hub (RHDH)
- Red Hat Dev Spaces
- Red Hat MTA (Migration Toolkit for Applications) v8.1.0
  - With Keycloak authentication
  - Solution server (Kai) enabled with LLM integration
  - LLM proxy enabled with OpenAI provider
  - Using external LiteLLM endpoint for AI inference

### Cluster Configuration
- Base path: `/home/sekumar/cluster01/cluster-gitops/clusters/cluster01/`
- Day 2 ApplicationSet: `day2-application.yaml`
- Pattern: Each operator in its own subdirectory

## Code Style Preferences

### YAML
- Use quotes for string values in specs (e.g., `"true"`, `"false"`, `"1Gi"`)
- Include annotations for sync-wave control
- Follow existing indentation patterns (2 spaces)

### Git Commits
- Include descriptive commit messages
- Multi-line format with summary and details
- Always include co-authorship: `Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>`
- Use heredoc format for commit messages to preserve formatting

### Communication
- Be concise and direct
- Show file paths with line numbers when referencing code
- Validate changes on cluster after deployment
- Provide URLs for deployed services

## Common Tasks

### Node Management
**SSH Access**: `ssh core@co1.skumars.net`

**Useful commands on node**:
- Check disk space: `df -h /sysroot`
- Container storage: `sudo du -sh /var/lib/containers/storage/*`
- List images: `sudo crictl images`
- Clean images: `sudo crictl rmi --prune`
- Restart kubelet: `sudo systemctl restart kubelet`
- Expand root filesystem: `sudo xfs_growfs /sysroot`

**Expanding Storage**:
1. Resize disk at hypervisor (e.g., 100GB → 200GB)
2. On node: `sudo growpart /dev/vda 4`
3. Remount if needed: `sudo mount -o remount,rw /sysroot`
4. Expand filesystem: `sudo xfs_growfs /sysroot`
5. Verify: `df -h /sysroot`
6. Restart kubelet if disk pressure: `sudo systemctl restart kubelet`

### Adding a New Operator
1. Create directory: `clusters/cluster01/<operator-name>/`
2. Create manifests: namespace, operatorgroup, subscription, CR
3. Use appropriate sync-waves
4. Commit and push to git
5. Verify ArgoCD creates the application
6. Monitor deployment and validate on cluster

### Troubleshooting Sync Issues
- Check sync-wave timing
- Add `SkipDryRunOnMissingResource=true` for CRD-dependent resources
- Increase sync-wave gap between operator installation and CR creation
- Verify operator CSV is in "Succeeded" phase before CR creation

### Troubleshooting Disk Pressure
When pods fail with disk-pressure taint:
1. **Diagnose**: SSH to node and check disk usage
   ```bash
   ssh core@co1.skumars.net "df -h /sysroot"
   ssh core@co1.skumars.net "sudo du -sh /var/lib/containers/storage/*"
   ```
2. **Check events**: Look for ephemeral-storage evictions
   ```bash
   oc get events -n <namespace> --sort-by='.lastTimestamp'
   ```
3. **Solutions**:
   - Expand root disk (/dev/vda) at hypervisor level
   - Use `growpart` and `xfs_growfs` to expand partition/filesystem
   - Clean up unused container images: `sudo crictl rmi --prune`
   - Note: Adding additional disks doesn't help - container storage is on root partition

### MTA Operator Configuration
When enabling kai components (solution server, LLM proxy), always configure resource limits:
```yaml
# Required kai resource parameters
kai_solution_server_container_limits_cpu: "1"
kai_solution_server_container_limits_memory: "2Gi"
kai_solution_server_container_requests_cpu: "500m"
kai_solution_server_container_requests_memory: "1Gi"
kai_llm_proxy_container_limits_cpu: "1"
kai_llm_proxy_container_limits_memory: "2Gi"
kai_llm_proxy_container_requests_cpu: "500m"
kai_llm_proxy_container_requests_memory: "1Gi"
```
**Note**: LLM proxy container image is ~5GB. Ensure sufficient disk space on root partition.

## Important Operational Notes

### Resource Management
- **Disk Pressure vs Memory Pressure**: Always check what resource is actually constrained
  - `node.kubernetes.io/disk-pressure` = ephemeral-storage (root partition)
  - `node.kubernetes.io/memory-pressure` = RAM
- **Container Images**: Large images (like LLM proxy ~5GB) consume significant root disk space
- **Root Partition Usage**: Monitor /sysroot - it holds OS, container images, and ephemeral storage

### MTA Deployment Lessons
- Enable kai components requires explicit resource limits configuration
- Without resource limits, pods may fail to start or get OOMKilled
- LLM proxy requires proper secret configuration (kai-api-keys with OPENAI_API_KEY and OPENAI_API_BASE)
- Solution server and LLM proxy are separate components with separate resource settings

### Diagnostic Workflow
1. Check pod status: `oc get pods -n <namespace>`
2. Check events: `oc get events -n <namespace> --sort-by='.lastTimestamp'`
3. Check node conditions: `oc describe node cluster01 | grep -A 5 "Conditions:"`
4. Check node resources: `oc adm top node`
5. SSH to node for deeper investigation if needed

## Project Context

This cluster is used for:
- Testing and demonstrating Red Hat OpenShift capabilities
- Day 2 operations automation
- GitOps best practices
- Operator lifecycle management
- Migration and modernization tooling (MTA)
- AI-assisted application modernization (Kai/LLM integration)
