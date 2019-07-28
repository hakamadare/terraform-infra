external-dns:
  aws:
    region: "${region}"

  podAnnotations:
    iam.amazonaws.com/role: "${iam_role}"
