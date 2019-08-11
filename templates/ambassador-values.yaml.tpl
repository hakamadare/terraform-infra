tls:
  dnsNames:
    %{~ for dnsName in split(",", fqdns) ~}
    - "${dnsName}"
    %{~ endfor ~}
  secret: ${tls_secret}
  issuer:
    name: ${acme_issuer}
    kind: ${acme_issuer_kind}

acme:
  provider: ${acme_provider}

ambassador:
  # use a DaemonSet with NLBs
  daemonSet: ${daemonset}

  service:
    type: LoadBalancer
    externalTrafficPolicy: Local

    # see https://www.getambassador.io/reference/ambassador-with-aws
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
      service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
      external-dns.alpha.kubernetes.io/hostname: "${fqdns}"
      getambassador.io/config: |
        ---
        apiVersion: ambassador/v1
        kind:  Module
        name:  ambassador
        config:
          use_remote_address: true
          use_proxy_proto: false
          gzip:
            enabled: true
            remove_accept_encoding_header: true
        ---
        apiVersion: ambassador/v1
        kind: Module
        name: tls
        config:
          server:
            enabled: true
            redirect_cleartext_from: 8080
