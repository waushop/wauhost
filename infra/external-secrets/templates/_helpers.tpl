{{/*
Expand the name of the chart.
*/}}
{{- define "external-secrets.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "external-secrets.fullname" -}}
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
{{- define "external-secrets.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "external-secrets.labels" -}}
helm.sh/chart: {{ include "external-secrets.chart" . }}
{{ include "external-secrets.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: secret-management
{{- end }}

{{/*
Selector labels
*/}}
{{- define "external-secrets.selectorLabels" -}}
app.kubernetes.io/name: {{ include "external-secrets.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "external-secrets.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "external-secrets.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the ClusterSecretStore
*/}}
{{- define "external-secrets.clusterSecretStoreName" -}}
{{- .Values.clusterSecretStore.name | default "cluster-secret-store" }}
{{- end }}

{{/*
Create the provider-specific auth configuration
*/}}
{{- define "external-secrets.providerAuth" -}}
{{- if eq .Values.secretStore.provider "aws" }}
secretRef:
  accessKeyID:
    name: {{ .Values.secretStore.auth.secretRef.accessKeyID.name }}
    key: {{ .Values.secretStore.auth.secretRef.accessKeyID.key }}
    namespace: {{ .Release.Namespace }}
  secretAccessKey:
    name: {{ .Values.secretStore.auth.secretRef.secretAccessKey.name }}
    key: {{ .Values.secretStore.auth.secretRef.secretAccessKey.key }}
    namespace: {{ .Release.Namespace }}
{{- else if eq .Values.secretStore.provider "vault" }}
tokenSecretRef:
  name: {{ .Values.secretStore.auth.tokenSecretRef.name }}
  key: {{ .Values.secretStore.auth.tokenSecretRef.key }}
  namespace: {{ .Release.Namespace }}
{{- else if eq .Values.secretStore.provider "azurekv" }}
secretRef:
  clientId:
    name: {{ .Values.secretStore.auth.secretRef.clientId.name }}
    key: {{ .Values.secretStore.auth.secretRef.clientId.key }}
    namespace: {{ .Release.Namespace }}
  clientSecret:
    name: {{ .Values.secretStore.auth.secretRef.clientSecret.name }}
    key: {{ .Values.secretStore.auth.secretRef.clientSecret.key }}
    namespace: {{ .Release.Namespace }}
{{- else if eq .Values.secretStore.provider "gcpsm" }}
secretRef:
  secretAccessKey:
    name: {{ .Values.secretStore.auth.secretRef.secretAccessKey.name }}
    key: {{ .Values.secretStore.auth.secretRef.secretAccessKey.key }}
    namespace: {{ .Release.Namespace }}
{{- end }}
{{- end }}