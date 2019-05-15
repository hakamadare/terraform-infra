tls:
  commonName: ${tls_commonname}
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

    # see https://www.getambassador.io/reference/ambassador-with-aws
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
      service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
      service.beta.kubernetes.io/aws-load-balancer-proxy-protocol: "*"
      getambassador.io/config: |
        ---
        apiVersion: ambassador/v1
        kind:  Module
        name:  ambassador
        config:
          use_remote_address: true
          use_proxy_proto: true
        ---
        apiVersion: ambassador/v1
        kind: Module
        name: tls
        config:
          server:
            enabled: true
            redirect_cleartext_from: 8080
