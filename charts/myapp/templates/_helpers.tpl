{{/*
Expand the name of the chart.
*/}}
{{- define "myapp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "myapp.fullname" -}}
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
{{- define "myapp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "myapp.labels" -}}
helm.sh/chart: {{ include "myapp.chart" . }}
{{ include "myapp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ .Values.partOf | default "enterprise-platform" }}
{{- if .Values.team }}
team: {{ .Values.team }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "myapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "myapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "myapp.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "myapp.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create image pull secret name
*/}}
{{- define "myapp.imagePullSecretName" -}}
{{- if .Values.image.pullSecrets }}
{{- .Values.image.pullSecrets | first }}
{{- else }}
{{- printf "%s-pull-secret" (include "myapp.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Return the proper image name
*/}}
{{- define "myapp.image" -}}
{{- $registryName := .Values.image.registry -}}
{{- $repositoryName := .Values.image.repository -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end }}

{{/*
Return the Key Vault name for secrets
*/}}
{{- define "myapp.keyVaultName" -}}
{{- .Values.secrets.keyVaultName | default (printf "%s-kv" .Release.Namespace) }}
{{- end }}

{{/*
Return the tenant ID for Workload Identity
*/}}
{{- define "myapp.tenantId" -}}
{{- .Values.workloadIdentity.tenantId | required "workloadIdentity.tenantId is required" }}
{{- end }}

{{/*
Return the client ID for Workload Identity
*/}}
{{- define "myapp.clientId" -}}
{{- .Values.workloadIdentity.clientId | required "workloadIdentity.clientId is required when workloadIdentity is enabled" }}
{{- end }}

{{/*
Generate resource requests and limits
*/}}
{{- define "myapp.resources" -}}
requests:
  cpu: {{ .Values.resources.requests.cpu | default "100m" }}
  memory: {{ .Values.resources.requests.memory | default "128Mi" }}
limits:
  cpu: {{ .Values.resources.limits.cpu | default "500m" }}
  memory: {{ .Values.resources.limits.memory | default "512Mi" }}
{{- end }}

{{/*
Generate pod security context
*/}}
{{- define "myapp.podSecurityContext" -}}
runAsNonRoot: true
runAsUser: {{ .Values.securityContext.runAsUser | default 1000 }}
runAsGroup: {{ .Values.securityContext.runAsGroup | default 1000 }}
fsGroup: {{ .Values.securityContext.fsGroup | default 1000 }}
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{/*
Generate container security context
*/}}
{{- define "myapp.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: {{ .Values.securityContext.readOnlyRootFilesystem | default true }}
runAsNonRoot: true
runAsUser: {{ .Values.securityContext.runAsUser | default 1000 }}
capabilities:
  drop:
    - ALL
{{- end }}
