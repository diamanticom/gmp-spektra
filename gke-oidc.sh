#!/bin/bash

cd $(dirname $0)

usage() {
  echo ""
  echo "GKE OIDC Setup Script"
  echo ""
  echo "Usage: $0 <Cluster Name> [-z <Cluster Zone>] [-p <Project ID>]"
  echo "                         [-s <Spektra FQDN>] [-c <CA cert file>,<CA key file>]"
  echo "  -h                  Print this usage."
  echo "  -s <Spektra FQDN>   Spektra fully qualified domain name, (required for create)."
  echo "  -z <Cluster Zone>   Node group instance type, (default: us-central1-a)."
  echo "  -p <Project ID>     GCP Project ID"
  echo "  -c <CA cert file>,<CA key file> CA cert and key pair to sign Spektra control plane TLS."
  exit 1
}

CLUSTER_NAME=
PROJECT=
OPERATION=update
SPEKTRA_FQDN=
SPEKTRA_PORT=5443
ZONE=us-central1-a
CA_CERT_FILE=

if [ -n "$1" -a "${1}" = "${1##-}" ]; then
    CLUSTER_NAME=$1
    shift
fi

while getopts ":hs:z:p:c:" options; do
    case "${options}" in
        s)
            if [ "${OPTARG%:*}" != "$OPTARG" ]; then
                SPEKTRA_FQDN=${OPTARG%:*}
                SPEKTRA_PORT=${OPTARG#*:}
            else
                SPEKTRA_FQDN=$OPTARG
            fi
            ;;
        z)
            ZONE=$OPTARG
            ;;
        p)
            PROJECT=$OPTARG
            ;;
        c)  
            CA_CERT_FILE=${OPTARG%,*}
            CA_KEY_FILE=${OPTARG#*,}
            ;;
        : | *)
            usage
            ;;
    esac
done

SPEKTRA_DEV_CA_CRT=
if [ -n "$CA_CERT_FILE" -a -f "$CA_CERT_FILE" ]; then
    if [ "$OSTYPE" = 'darwin' ]; then
        SPEKTRA_DEV_CA_CRT=$(cat $CA_CERT_FILE | base64)
    else
        SPEKTRA_DEV_CA_CRT=$(cat $CA_CERT_FILE | base64 -w 0)
    fi
fi
if [ -n "$CA_KEY_FILE" -a -f "$CA_KEY_FILE" ]; then
    if [ "$OSTYPE" = 'darwin' ]; then
        SPEKTRA_DEV_CA_KEY=$(cat $CA_KEY_FILE | base64)
    else
        SPEKTRA_DEV_CA_KEY=$(cat $CA_KEY_FILE | base64 -w 0)
    fi
fi
if [ $SPEKTRA_PORT -ne 443 ]; then
    ISSUER_URI_HOST="${SPEKTRA_FQDN}:${SPEKTRA_PORT}"
else
    ISSUER_URI_HOST=${SPEKTRA_FQDN}
fi

case $OPERATION in
    update )
        # update cluster to enabled OIDC
        gcloud container clusters update $CLUSTER_NAME --zone=$ZONE --project=$PROJECT --enable-identity-service

        if [ $? -ne 0 ]; then
            exit 1
        fi

        # get cluster kubeconfig
        gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE --project=$PROJECT
        if [ $? -ne 0 ]; then
            exit 1
        fi

        # configure OIDC
        echo -n "Waiting for OIDC to start: "
        OIDC_READY=0
        while [ $OIDC_READY -eq 0 ]; do
            echo -n "."
            sleep 3
            if ! kubectl get clientconfig default -n kube-public > /dev/null 2>&1; then continue; fi
            OIDC_READY=1
        done
        echo ""
        cat - > /tmp/client-config-patch.yaml <<EOF
spec:
  authentication:
  - name: oidc
    oidc:
      clientID: kubernetes.local
      certificateAuthorityData: "${SPEKTRA_DEV_CA_CRT}"
      issuerURI: https://${ISSUER_URI_HOST}/v1/identity/oidc
      cloudConsoleRedirectURI: https://console.cloud.google.com/kubernetes/oidc
      kubectlRedirectURI: https://${ISSUER_URI_HOST}
      userClaim: username
      groupsClaim: groups
      userPrefix: "-"
EOF
        kubectl patch clientconfig default -n kube-public --type merge --patch-file /tmp/client-config-patch.yaml
        rm -f /tmp/client-config-patch.yaml

        # get OIDC_VIP ingress address
        OIDC_INGRESS_ADDRESS=$(kubectl -n kube-public get clientconfig default -o jsonpath="{.spec.server}")

        echo ""
        echo "---------------------------------------------------------------"
        echo "Please provide the following values in the GCP Marketplace form:"
        echo "---------------------------------------------------------------"
        echo "OIDC_VIP: $(echo "$OIDC_INGRESS_ADDRESS" | sed -e 's|^https://||' -e 's|:.*||')"
        echo ""
        echo "Spektra_FQDN: ${SPEKTRA_FQDN}"
        echo ""
        echo "Base64-encoded CA Certificate File: ${SPEKTRA_DEV_CA_CRT}"
        echo ""
        echo "Base64-encoded CA Key File: ${SPEKTRA_DEV_CA_KEY}"
        ;;
esac
