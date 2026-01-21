{{/*
Expand the name of the chart.
*/}}
{{- define "hostedcluster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "hostedcluster.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "hostedcluster.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "hostedcluster.labels" -}}
helm.sh/chart: {{ include "hostedcluster.chart" . }}
{{ include "hostedcluster.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "hostedcluster.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hostedcluster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Get cluster name
*/}}
{{- define "hostedcluster.clusterName" -}}
{{- .Values.cluster.name }}
{{- end }}

{{/*
Get base domain for the cluster
Auto-generate if autoBaseDomain is true, otherwise use specified value
*/}}
{{- define "hostedcluster.baseDomain" -}}
{{- if .Values.cluster.autoBaseDomain }}
{{- printf "%s.%s" .Values.cluster.name .Values.cluster.rootDomain }}
{{- else }}
{{- .Values.cluster.baseDomain }}
{{- end }}
{{- end }}

{{/*
Get nodepool name
*/}}
{{- define "hostedcluster.nodePoolName" -}}
{{- if .Values.nodePool.name }}
{{- .Values.nodePool.name }}
{{- else }}
{{- printf "%s-pool" .Values.cluster.name }}
{{- end }}
{{- end }}

{{/*
Get pull secret name
*/}}
{{- define "hostedcluster.pullSecretName" -}}
{{- if .Values.secrets.useAutoSecretNames }}
{{- printf "pullsecret-cluster-%s" .Values.cluster.name }}
{{- else }}
{{- .Values.secrets.pullSecretName }}
{{- end }}
{{- end }}

{{/*
Get SSH key secret name
*/}}
{{- define "hostedcluster.sshKeyName" -}}
{{- if .Values.secrets.useAutoSecretNames }}
{{- printf "sshkey-cluster-%s" .Values.cluster.name }}
{{- else }}
{{- .Values.secrets.sshKeyName }}
{{- end }}
{{- end }}

{{/*
Get infra kubeconfig secret name
*/}}
{{- define "hostedcluster.infraKubeConfigSecretName" -}}
{{- if .Values.infrastructure.useAutoSecretNames }}
{{- printf "infra-cluster-%s" .Values.cluster.name }}
{{- else }}
{{- .Values.infrastructure.infraKubeConfigSecretName }}
{{- end }}
{{- end }}

{{/*
Get etcd encryption key secret name
*/}}
{{- define "hostedcluster.etcdEncryptionKeyName" -}}
{{- printf "%s-etcd-encryption-key" .Values.cluster.name }}
{{- end }}
