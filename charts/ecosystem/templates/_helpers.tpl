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

{{/*
  Returns the location of the encryption keys file where it will be mounted in a pod
*/}}
{{- define "ecosystem.encryption.keys.path" -}}
  {{- print "/galasa/encryption/encryption-keys.yaml" }}
{{- end -}}

{{/*
  Returns the directory path where the encryption keys file will be mounted under
*/}}
{{- define "ecosystem.encryption.keys.directory" -}}
  {{- dir (include "ecosystem.encryption.keys.path" .) }}
{{- end -}}

{{/*
  Returns the name of the secret that stores encryption keys
*/}}
{{- define "ecosystem.encryption.keys.secret.name" -}}
  {{- empty .Values.encryption.keysSecretName | ternary (printf "%s-encryption-secret" .Release.Name) (.Values.encryption.keysSecretName) }}
{{- end -}}

{{/*
  Returns the ETCD URL for the Configuration Property Store
*/}}
{{- define "cps.url" -}}
  {{- contains "RELEASE_NAME" .Values.cpsUrl | ternary (.Values.cpsUrl | replace "RELEASE_NAME" .Release.Name) (.Values.cpsUrl) }}
{{- end -}}

{{/*
  Returns the ETCD URL for the Dynamic Status Store
*/}}
{{- define "dss.url" -}}
  {{- contains "RELEASE_NAME" .Values.dssUrl | ternary (.Values.dssUrl | replace "RELEASE_NAME" .Release.Name) (.Values.dssUrl) }}
{{- end -}}

{{/*
  Returns the ETCD URL for the Credentials Store
*/}}
{{- define "creds.url" -}}
  {{- contains "RELEASE_NAME" .Values.credsUrl | ternary (.Values.credsUrl | replace "RELEASE_NAME" .Release.Name) (.Values.credsUrl) }}
{{- end -}}

{{/*
  Returns the extra bundles to load when starting the framework
*/}}
{{- define "framework.extra.bundles" -}}
  {{- print "dev.galasa.cps.etcd,dev.galasa.ras.couchdb,dev.galasa.events.kafka" }}
{{- end -}}
