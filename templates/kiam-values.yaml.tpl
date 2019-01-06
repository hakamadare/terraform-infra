# Values for our chart
env: ${env}

# Values for the upstream kiam chart
kiam:
  agent:
    podLabels:
      app.kubernetes.io/name: ${name}
      app.kubernetes.io/instance: ${name}-${env}
      app.kubernetes.io/version: ${version}
      app.kubernetes.io/component: agent
      app.kubernetes.io/part-of: ${name}-${version}
      app.kubernetes.io/managed-by: Tiller

    image:
      tag: ${version}

    tlsSecret: ${agent_secret}

  server:
    podLabels:
      app.kubernetes.io/name: ${name}
      app.kubernetes.io/instance: ${name}-${env}
      app.kubernetes.io/version: ${version}
      app.kubernetes.io/component: server
      app.kubernetes.io/part-of: ${name}-${version}
      app.kubernetes.io/managed-by: Tiller

    image:
      tag: ${version}

    assumeRoleArn: ${assume_role_arn}

    tlsSecret: ${server_secret}

#  vim: set et fenc= ff=unix ft=yaml sts=2 sw=2 ts=2 : 
