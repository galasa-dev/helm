#
# Copyright contributors to the Galasa project
#
# SPDX-License-Identifier: EPL-2.0
#

{{/*
  Returns the URI scheme of the host serving the ecosystem
*/}}
{{- define "ecosystem.host.scheme" -}}
  {{- empty .Values.ingress.tls | ternary "http" "https" }}
{{- end -}}

{{/*
  Returns the external URL of the ecosystem
*/}}
{{- define "ecosystem.host.url" -}}
  {{- printf "%s://%s" (include "ecosystem.host.scheme" .) (.Values.externalHostname) }}
{{- end -}}
