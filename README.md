# Spektra Installation on GKE

## Prerequisites
A GKE cluster should have the following configurations:
- GKE cluster with K8S version **1.28**
- There should be at least one worker node with a minimum configuration of **E2-Standard-4 [4 VCPU and 16GB Memory]**.
- You should enable the **Identity Service**. Using **gcloud**, enable the service by using the `enable-identity-service` flag.
 ```bash
 # For new clusters
 gcloud container clusters create CLUSTER_NAME --enable-identity-service
 
 # For existing clusters
 gcloud container clusters update CLUSTER_NAME --enable-identity-service
```
Make sure OIDC pods are running once the identity service is enabled.

- In order to configure **GKE OIDC**, Spektra’s **FQDN Issuer URL** needs a **CA** certificate.

## Installation Steps
### Configure OIDC
- To configure OIDC, create a patch file **/tmp/client-config-patch.yaml** with FQDN and CA certificates:
```json
spec:
 authentication:
 - name: oidc
   oidc:
    clientID: kubernetes.local
    certificateAuthorityData: "<CA_CERT_FILE_BASE64>"
    issuerURI: https://<ISSUER_URI_HOST>:5443/v1/identity/oidc
    cloudConsoleRedirectURI: https://console.cloud.google.com/kubernetes/oidc
    kubectlRedirectURI: https://<ISSUER_URI_HOST>:5443
    userClaim: username
    groupsClaim: groups
    userPrefix: "-"
```
- Run the following command to set OIDC authentication:
```bash
kubectl patch clientconfig default -n kube-public --type merge --patch-file /tmp/client-config-patch.yaml

# Expected Output:
clientconfig.authentication.gke.io/default patched
```

- Run the following command to get the OIDC VIP address:

```bash
kubectl -n kube-public get clientconfig default -o jsonpath="{.spec.server}"

# Expected Output:
https://<OIDC_VIP>:443
```

### Set up the Cloud DNS for your FQDN.
- If the DNS entry already exists, skip this step:
```bash
gcloud dns managed-zones create <snakecase DNS zone name>-dns --description=<snakecase DNS zone name>-dns --dns-name=<DNS zone name> --visibility=private --networks=default

gcloud dns record-sets create <FQDN of your cluster> --rrdatas=8.8.8.8 --type=A --ttl=60 --zone=<snakecase DNS zone name>-dns
```

### Deploy the Spektra (BYOL) in GCP Marketplace
- **Deploy Spektra (BYOL) with required fields.**
    - **OIDC_VIP** It is the OIDC VIP address of the GKE cluster.
    - **FQDN** is fqdn used for cluster.
    - **CA_CERT_FILE_BASE64** is valid .crt in base64 format.
    - **CA_KEY_FILE_BASE64** is valid .key in base64 format.

### Check Status
- Run the following command to check the status of all spektra system pods. All pods will be in spektra-system namespace.

> **Note:** All Spektra system pods will be ready in 5-7 minutes.
```bash
watch "kubectl get po -n spektra-system"
```

- Ensure the following conditions are met before setting up spektra domain:
```bash
kubectl wait pods -l app.kubernetes.io/instance=vault -n spektra-system --for condition=Initialized --timeout=0
    # pod/vault-0 condition met

kubectl wait pods -l app.kubernetes.io/instance=spektra-ingress -n spektra-system --for condition=Ready --timeout=0
    # pod/spektra-ingress-ingress-nginx-controller-647d97c54b-skbrs condition met

kubectl wait pods -l statefulset.kubernetes.io/pod-name=catalog-mongo-0 -n spektra-system --for condition=Ready --timeout=0
    # pod/catalog-mongo-0 condition met

kubectl wait pods -l control-plane=controller-manager -n spektra-system --for condition=Ready --timeout=0
    # pod/capdi-controller-manager-b88bcd75b-nvtvl condition met
    # pod/capi-attacher-controller-manager-686f6f5559-wdvtz condition met
    # pod/capi-controller-manager-5f5775cb48-trccx condition met
    # pod/capi-kubeadm-bootstrap-controller-manager-7d99996ff6-vwlqt condition met
    # pod/capi-kubeadm-control-plane-controller-manager-565fb56c6f-tnr6k condition met
    # pod/tenant-controller-manager-6c56dbdc86-r2z6k condition met

kubectl wait pods -l control-plane=upgrade-manager -n spektra-system --for condition=Ready --timeout=0
   # pod/upgrade-manager-7868d69f4b-8zvsg condition met
```

## Configuring Domain
- Get the ingress address as mentioned:
```bash
kubectl -n spektra-system get svc spektra-ingress-ingress-nginx-controller -o jsonpath="{.status.loadBalancer.ingress[0].ip}"
```
- Add the host entry with ingress address.
```bash
sudo bash -c 'echo "<ingress-ip-address> <spektrafqdn> " >> /etc/hosts'
```
- Update the DNS record set by adding ingress entry.
```bash
gcloud dns record-sets update <spektra-fqdn> --rrdatas=<ip-address> --type=A --ttl=60 --zone=zone-name
```
- Open the spektra URL: **https://<fqdn>:5443** and configure the Domain.
- Navigate to the Domain setup page and enter the following, and select **Create Domain**:
    - Domain Name
    - User Name
    - Pasword
    - Confirm Password

- Copy the recovery key and select Continue to Login
- On the Eula agreement page select the checkbox and then select Agree and Continue.
- Enter the login credentails and select Login. You are directed to SP Domain home page.
- Ensure the following conditions are met before setting up spektra domain:
```bash
kubectl wait pods -l app.kubernetes.io/instance=vault -n spektra-system --for condition=Ready --timeout=0
    # pod/vault-0 condition met

kubectl wait pods -l statefulset.kubernetes.io/pod-name=spektra-minio-pool-0-0 -n spektra-system --for condition=Ready --timeout=0
    # pod/spektra-minio-pool-0-0 condition met

kubectl wait pods -l app.kubernetes.io/name=query -n spektra-system --for condition=Ready --timeout=0
    # pod/spektra-thanos-query-6dd9c57795-bq7cz condition met

kubectl wait pods -l monitoring.banzaicloud.io/storeendpoint=spektra-thanos -n spektra-system --for condition=Ready --timeout=0
    # pod/spektra-thanos-spektra-thanos-store-5569d45cf-7mkxs condition met

kubectl wait pods -l statefulset.kubernetes.io/pod-name=spektra-thanos-receiver-soft-tenant-0 -n spektra-system --for condition=Ready --timeout=0
    # pod/spektra-thanos-receiver-soft-tenant-0 condition met

kubectl wait pods -l statefulset.kubernetes.io/pod-name=spektra-thanos-receiver-soft-tenant-1 -n spektra-system --for condition=Ready --timeout=0
    # pod/spektra-thanos-receiver-soft-tenant-1 condition met
```