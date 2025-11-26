{{/*
Expand the name of the chart.
*/}}
{{- define "dragonfly.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "dragonfly.fullname" -}}
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
{{- define "dragonfly.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "dragonfly.labels" -}}
helm.sh/chart: {{ include "dragonfly.chart" . }}
{{ include "dragonfly.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "dragonfly.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dragonfly.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Dragonfly host
*/}}
{{- define "dragonfly.host" -}}
{{ include "dragonfly.fullname" . }}
{{- end }}

{{/*
Dragonfly connection URL
Usage: {{ include "dragonfly.url" . }}
Returns: redis://[:password@]host:port
*/}}
{{- define "dragonfly.url" -}}
{{- if .Values.auth.password }}
redis://:{{ .Values.auth.password }}@{{ include "dragonfly.fullname" . }}:{{ .Values.service.port }}
{{- else }}
redis://{{ include "dragonfly.fullname" . }}:{{ .Values.service.port }}
{{- end }}
{{- end }}
