k8s-spot-rescheduler:
  image:
    tag: "${version}"

  tolerations:
  - key: "node-role.kubernetes.io/worker"
    operator: "Equal"
    value: "true"
    effect: "PreferNoSchedule"

  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
          - key: "node-role.kubernetes.io/worker"
            operator: "In"
            values:
            - "true"
