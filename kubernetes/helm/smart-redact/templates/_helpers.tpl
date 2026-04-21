{{/*
Common labels
*/}}
{{- define "smart-redact.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.global.imageTag | quote }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{/*
Selector labels for a specific component
*/}}
{{- define "smart-redact.selectorLabels" -}}
app.kubernetes.io/name: smart-redact
app.kubernetes.io/component: {{ .component }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Image tag - uses component-specific tag if set, otherwise global
*/}}
{{- define "smart-redact.imageTag" -}}
{{- . | default $.Values.global.imageTag | default "latest" -}}
{{- end }}
