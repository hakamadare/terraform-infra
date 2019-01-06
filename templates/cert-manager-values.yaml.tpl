# Values for our chart
env: ${env}

# Values for the upstream cert-manager chart
cert-manager:
  image:
    tag: ${version}

  podLabels:
    app.kubernetes.io/name: ${name}
    app.kubernetes.io/instance: ${name}-${env}
    app.kubernetes.io/version: ${version}
    app.kubernetes.io/component: ${name}
    app.kubernetes.io/part-of: ${name}-${version}
    app.kubernetes.io/managed-by: Tiller

  podAnnotations:
    iam.amazonaws.com/role: ${iam_role}

#  vim: set et fenc= ff=unix ft=yaml sts=2 sw=2 ts=2 : 
