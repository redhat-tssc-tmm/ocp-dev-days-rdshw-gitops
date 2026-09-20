{{/*
Expand the name of the chart.
*/}}
{{- define "rhacs-central.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Determine target namespace
*/}}
{{- define "rhacs-central.namespace" -}}
{{- default .Release.Namespace .Values.namespace }}
{{- end }}
