{{/*
Determine target namespace
*/}}
{{- define "rhacs-secured-cluster.namespace" -}}
{{- default .Release.Namespace .Values.namespace }}
{{- end }}
