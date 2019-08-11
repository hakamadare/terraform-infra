---
mapping:
  fqdn: "${fqdn}"
  port: ${service_port}
  service: "${service_name}"

chartmuseum:
  replica:
    annotations:
      iam.amazonaws.com/role: "${iam_role}"

  env:
    open:
      CHART_URL: "https://${fqdn}"
      AUTH_ANONYMOUS_GET: "true"
      DISABLE_METRICS: "false"
      DISABLE_API: "false"
    secret:
      BASIC_AUTH_USER: "${basic_auth_user}"
      BASIC_AUTH_PASS: "${basic_auth_pass}"
