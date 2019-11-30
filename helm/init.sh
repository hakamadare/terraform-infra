#!/bin/bash
set -e

HELM2='/usr/local/opt/helm@2/bin/helm'

script_dir=$(dirname "$0")

if [ -d "${script_dir}" ]; then

  helm_rbac_yaml="${script_dir}/rbac-config.yaml"
  if [ -f "$helm_rbac_yaml" ]; then
    kubectl apply -f "${helm_rbac_yaml}"
  fi

  $HELM2 init \
    --upgrade \
    --tiller-tls \
    --tiller-tls-cert ~/.helm/cert.pem \
    --tiller-tls-key ~/.helm/key.pem \
    --tls-ca-cert ~/.helm/ca.pem  \
    --tiller-tls-verify \
    --service-account tiller \
    --node-selectors "node-role.kubernetes.io/worker"="true" \
    --history-max 200

fi
