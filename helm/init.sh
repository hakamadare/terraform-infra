#!/bin/bash
set -e

script_dir=$(dirname "$0")

if [ -d "${script_dir}" ]; then

  helm_rbac_yaml="${script_dir}/rbac-config.yaml"
  if [ -f "$helm_rbac_yaml" ]; then
    kubectl apply -f "${helm_rbac_yaml}"
  fi

  helm init \
    --upgrade \
    --tiller-tls \
    --tiller-tls-cert ~/.helm/cert.pem \
    --tiller-tls-key ~/.helm/key.pem \
    --tls-ca-cert ~/.helm/ca.pem  \
    --tiller-tls-verify \
    --service-account tiller \
    --history-max 200

fi
