http.enabled: true
http.host: 0.0.0.0
http.port: 5066

queue.mem:
  events: {{ if .queueEvents }}{{ .queueEvents }}{{ else }}8192{{ end }}

filebeat.config:
  inputs:
    enabled: true
    path: ${path.home}/inputs.d/*.yml
    reload.enabled: true
    reload.period: 10s

filebeat.inputs: 
- type: log
  enabled: true
  fields_under_root: true
  paths:
  - /var/log/dockerd.log
  fields:
    cluster: ${CLUSTER_ID}
    node_name: ${NODE_NAME}
    component: system.docker
    {{- range $k,$v := .fields }}
    {{ $k }}: {{ $v }}
    {{- end }}
  {{ if .multilinePattern -}}
  {{- if ne .multilinePattern ""}}
  multiline:
    pattern: {{ .multilinePattern }}
    negate: false
    match: after
  {{- end -}}
  {{- end }}
  {{ if .ignoreOlder -}}
  ignore_older: {{ .ignoreOlder }}
  {{- end }}  
- type: log
  enabled: true
  fields_under_root: true
  paths:
  - /var/log/kubelet.log
  fields:
    cluster: ${CLUSTER_ID}
    node_name: ${NODE_NAME}
    component: system.kubelet
    {{- range $k,$v := .fields }}
    {{ $k }}: {{ $v }}
    {{- end }}
  {{ if .multilinePattern -}}
  {{- if ne .multilinePattern ""}}
  multiline:
    pattern: {{ .multilinePattern }}
    negate: false
    match: after
  {{- end -}}
  {{- end }}
  {{ if .ignoreOlder -}}
  ignore_older: {{ .ignoreOlder }}
  {{- end }} 
# TODO: etcd, apiserver and more..

processors:
- drop_fields:
    fields: ["beat", "host.name", "input.type", "prospector.type", "offset", "source", "log"]
- rename:
    fields:
    - from: message
      to: log
    ignore_missing: true

{{- if eq .type "elasticsearch" }}
setup.template.enabled: true
setup.template.overwrite: false
setup.template.name: k8s-log-template
setup.template.pattern: logstash-*
setup.template.json.name: k8s-log-template
setup.template.json.path: /etc/filebeat/k8s-log-template.json
setup.template.json.enabled: true

output.elasticsearch:
    hosts:
    {{- range .hosts }}
    - {{ . }}
    {{- end }}
    index: logstash-%{+yyyy.MM.dd}
{{- end }}

{{- if eq .type "kafka" }}
output.kafka:
    enabled: true
    hosts:
    {{- range .brokers }}
    - {{ . }}
    {{- end }}
    topic: {{ .topic }}
    version: {{ .version }}
    {{- if .max_message_bytes }}
    max_message_bytes: {{ .max_message_bytes }}
    {{- end }}
{{- end }}

{{- if eq .type "logstash" }}
output.logstash:
    hosts:
    {{- range .logstashHost }}
    - {{ . }}
    {{- end }}
    {{- if .loadbalance }}
    loadbalance: {{- if eq .loadbalance "true"}}true{{- else }}false{{- end }}
    {{- end }}
    worker: {{ if .worker }}{{ .worker }}{{ else }}4{{ end }}
    pipelining: {{ if .pipelining }}{{ .pipelining }}{{ else }}3{{ end }}
    bulk_max_size: {{ if .bulkMaxSize }}{{ .bulkMaxSize }}{{ else }}4096{{ end }}
{{- end }}
