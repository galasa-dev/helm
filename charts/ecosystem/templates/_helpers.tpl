#
# Copyright contributors to the Galasa project
#
# SPDX-License-Identifier: EPL-2.0
#

{{/*
  Returns the URL scheme of the host serving this ecosystem
*/}}
{{- define "ecosystem.hostScheme" -}}
  {{- empty .Values.ingress.tls | ternary "http" "https"}}
{{- end -}}

{{/*
  Returns the external URL of the ecosystem
*/}}
{{- define "ecosystem.hostUrl" -}}
  {{- printf "%s://%s" (include "ecosystem.hostScheme" .) (.Values.externalHostname) }}
{{- end -}}
