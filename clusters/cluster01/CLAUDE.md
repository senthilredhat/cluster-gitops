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

### Deployed Operators (as of 2026-04-07)
- OpenShift GitOps (ArgoCD) - Day 1
- OpenShift Virtualization
- nmstate-operator (network configuration)
- Red Hat Developer Hub (RHDH)
- Red Hat Dev Spaces
- Red Hat MTA (Migration Toolkit for Applications) v8.1.0
  - With Keycloak authentication
  - Solution server (Kai) enabled with LLM integration

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

## Project Context

This cluster is used for:
- Testing and demonstrating Red Hat OpenShift capabilities
- Day 2 operations automation
- GitOps best practices
- Operator lifecycle management
- Migration and modernization tooling (MTA)
