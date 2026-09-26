{{- define "parasol-insurance-secured-tenant.username" -}}
{{ .Values.tenant.username }}
{{- end -}}

{{- define "parasol-insurance-secured-tenant.prefix" -}}
{{ .Values.tenant.username }}
{{- end -}}

{{/*
ArgoCD AppProject name. Must match the project created by
agnosticd.namespaced_workloads.ocp4_workload_tenant_openshift_gitops
which uses the default prefix "appproject".
*/}}
{{- define "parasol-insurance-secured-tenant.argocd-project" -}}
appproject-{{ .Values.tenant.username }}
{{- end -}}
