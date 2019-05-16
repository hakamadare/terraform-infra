k8s-spot-rescheduler:
  image:
    tag: "${version}"

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
