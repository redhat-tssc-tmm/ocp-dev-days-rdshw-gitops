{{/*
Determine target namespace
*/}}
{{- define "tpa-prereqs.namespace" -}}
{{- default .Release.Namespace .Values.namespace }}
{{- end }}
