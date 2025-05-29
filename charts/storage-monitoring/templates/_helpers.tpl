{{/*
Expand the name of the chart.
*/}}
{{- define "storage-monitoring.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "storage-monitoring.fullname" -}}
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
{{- define "storage-monitoring.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "storage-monitoring.labels" -}}
helm.sh/chart: {{ include "storage-monitoring.chart" . }}
{{ include "storage-monitoring.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: storage-monitoring
{{- end }}

{{/*
Selector labels
*/}}
{{- define "storage-monitoring.selectorLabels" -}}
app.kubernetes.io/name: {{ include "storage-monitoring.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "storage-monitoring.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "storage-monitoring.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create a default fully qualified prometheus name.
*/}}
{{- define "storage-monitoring.prometheus.fullname" -}}
{{- printf "%s-%s" (include "storage-monitoring.fullname" .) "prometheus" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified grafana name.
*/}}
{{- define "storage-monitoring.grafana.fullname" -}}
{{- printf "%s-%s" (include "storage-monitoring.fullname" .) "grafana" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified alertmanager name.
*/}}
{{- define "storage-monitoring.alertmanager.fullname" -}}
{{- printf "%s-%s" (include "storage-monitoring.fullname" .) "alertmanager" | trunc 63 | trimSuffix "-" }}
{{- end }}