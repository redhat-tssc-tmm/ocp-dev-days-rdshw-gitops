{{/*
Determine target namespace
*/}}
{{- define "rhacs-sso-config.namespace" -}}
{{- default .Release.Namespace .Values.namespace }}
{{- end }}
