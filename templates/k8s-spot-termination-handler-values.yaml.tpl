k8s-spot-termination-handler:
  detachAsg: "${detach_asg}"

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
