{{/*
Determine target namespace
*/}}
{{- define "rhtas-instance.namespace" -}}
{{- default .Release.Namespace .Values.namespace }}
{{- end }}
