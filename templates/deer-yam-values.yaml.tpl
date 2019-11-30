---
image:
  repository: "${registry}"
  tag: latest
  pullPolicy: "${image_pull_policy}"

nameOverride: "${name}"
fullnameOverride: "${name}"

mapping:
  host: "static-deeryam.vecna.org"
  headers:
    x-cdn-uuid: "${cdn_uuid}"
  retry_policy:
    retry_on: "5xx"
    num_retries: 3
    per_try_timeout: "5s"

deployment:
  annotations:
    configmap.reloader.stakater.com/reload: "${name}-version"
  podAnnotations:
    iam.amazonaws.com/role: "${iam_role}"

tolerations:
- key: "node-role.kubernetes.io/worker"
  operator: "Equal"
  value: "true"
  effect: "PreferNoSchedule"
