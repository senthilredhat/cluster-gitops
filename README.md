# cluster-gitops

## Getting started with this repo

<!-- Press the `Use This Template` button at the right top corner of this page and follow the github instructions to create a detached copy of this repo.

Once you have a copy of this repo in your organization, you have to seed your Hub cluster to point to this repo. -->

To do so you can simply run this commands, however you might want to implement these steps in different ways in your environment:

```sh
export gitops_repo=https://github.com/senthilredhat/cluster-gitops.git
oc apply -f .bootstrap/subscription.yaml
oc apply -f .bootstrap/cluster-rolebinding.yaml
oc apply -f .bootstrap/argocd.yaml
envsubst < .bootstrap/root-application.yaml | oc apply -f -
```