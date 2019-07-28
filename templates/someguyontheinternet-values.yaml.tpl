---
image:
  repository: "${registry}"
  tag: latest
  pullPolicy: "${image_pull_policy}"

nameOverride: "${name}"
fullnameOverride: "${name}"

mapping:
  host: "static-someguyontheinternet.vecna.org"

deployment:
  podAnnotations:
    iam.amazonaws.com/role: "${iam_role}"

tolerations:
- key: "node-role.kubernetes.io/worker"
  operator: "Equal"
  value: "true"
  effect: "PreferNoSchedule"
