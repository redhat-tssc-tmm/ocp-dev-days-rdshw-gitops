{{- define "tpa-tenant.username" -}}
{{ .Values.tenant.username }}
{{- end -}}

{{- define "tpa-tenant.prefix" -}}
{{ .Values.tenant.username }}
{{- end -}}

{{/*
ArgoCD AppProject name.
*/}}
{{- define "tpa-tenant.argocd-project" -}}
appproject-{{ .Values.tenant.username }}
{{- end -}}
