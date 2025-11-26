{{/*
Expand the name of the chart.
*/}}
{{- define "ontu-schedule-bot.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "ontu-schedule-bot.fullname" -}}
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
{{- define "ontu-schedule-bot.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ontu-schedule-bot.labels" -}}
helm.sh/chart: {{ include "ontu-schedule-bot.chart" . }}
{{ include "ontu-schedule-bot.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ontu-schedule-bot.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ontu-schedule-bot.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Admin backend URL helper
Constructs the full URL to the admin backend service
*/}}
{{- define "ontu-schedule-bot.adminBackendUrl" -}}
{{ .Values.adminBackend.protocol }}://{{ .Values.adminBackend.host }}:{{ .Values.adminBackend.port }}{{ .Values.adminBackend.apiPath }}
{{- end }}
