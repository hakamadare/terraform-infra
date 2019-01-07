#!/bin/bash
set -e

SECRET="$1"
MKTEMP=$(which mktemp)
KUBECTL=$(which kubectl)
JQ=$(which jq)

JSONTMP=$($MKTEMP -d)
CA=${JSONTMP}/ca.json
CRT=${JSONTMP}/crt.json
TLS=${JSONTMP}/tls.json
NEW=${JSONTMP}/new.json

$KUBECTL -n cert-manager get secret intermediate-ca -o json \
  | $JQ 'map_values( if type == "object" then ( if . | has("tls.crt") then  . + {"ca.crt": ."tls.crt"} | del(."tls.crt") | del(."tls.key")  else empty end ) else empty end)' > $CA

$KUBECTL -n kiam get secret $SECRET -o json > $CRT

$JQ -n 'reduce inputs as $i ({}; . * $i)' $CA $CRT | $JQ '.metadata.name = .metadata.name + "-tls"' > $TLS

$KUBECTL -n kiam create -f $TLS

cat $TLS \
  | $JQ 'map_values( if type == "object" then ( if . | has("ca.crt") then  . + {"cert": ."tls.crt", "key": ."tls.key", "ca": ."ca.crt"} | del(."tls.crt") | del(."tls.key") | del(."ca.crt") else . end ) else . end) | .metadata.name = .metadata.name + "-ca" | .type = "Opaque"' > $NEW

$KUBECTL -n kiam create -f $NEW

rm -rf $JSONTMP
