# Values for our chart
env: ${env}

route53:
  region: ${region}

acme:
  email: ${acme_email}

# Values for the upstream cert-manager chart
cert-manager:
  image:
    tag: ${version}

  podAnnotations:
    iam.amazonaws.com/role: ${iam_role}

#  vim: set et fenc= ff=unix ft=yaml sts=2 sw=2 ts=2 : 
