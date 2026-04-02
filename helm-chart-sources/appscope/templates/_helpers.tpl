{{/*
Extract the path from File or Unix variant
*/}}
{{- define "appscope.extractUnixFilePath" -}}
{{- $input_cfg := index . 0 -}}
{{- $filePath := split "://" $input_cfg -}}
{{- print $filePath._1 }}
{{- end -}}

{{/*
Extract the port from TCP, UDP or TLS variant
*/}}
{{- define "appscope.extractPort" -}}
{{- $input_cfg := index . 0 -}}
{{- $netPath := split "://" $input_cfg -}}
{{- $host_port := split ":" $netPath._1 -}}
{{- print $host_port._1 }}
{{- end -}}

{{/*
Extract the host from TCP, UDP or TLS variant
*/}}
{{- define "appscope.extractHost" -}}
{{- $input_cfg := index . 0 -}}
{{- $netPath := split "://" $input_cfg -}}
{{- $host_port := split ":" $netPath._1 -}}
{{- print $host_port._0 }}
{{- end -}}
