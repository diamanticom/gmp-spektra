# Spektra Installation on GKE

## Prerequisites
A GKE cluster should have the following configurations:
- GKE cluster with K8S version **1.27** or **1.28**
- There should be at least one worker node with a minimum configuration of **E2-Standard-4 [4 VCPU and 16GB Memory]**.
- In order to configure **GKE OIDC**, Spektra’s **FQDN Issuer URL** needs a **CA** certificate.

## Installation Steps
### Configure OIDC
- To configure OIDC use the following script <a href="https://raw.githubusercontent.com/diamanticom/gmp-spektra/master/gke-oidc.sh">here</a>.
```bash
./gke-oidc.sh <Cluster Name> -z <Cluster Zone> -s <Spektra FQDN> -c <CA cert file>,<CA key file>
```

### Setup Cloud DNS for the Spektra FQDN
- If the DNS zone already exists, skip this step:
```bash
gcloud dns managed-zones create <DNS zone name> --description=<DNS zone name description> --dns-name=<FQDN minus hostname> --visibility=private --networks=default
```

### Check Status
- Run the following command to check the status of all spektra system pods. All pods will be in spektra-system namespace.
> **Note:** All Spektra system pods will be ready in 5-7 minutes.
```bash
watch "kubectl get po -n spektra-system"
```
- Ensure the following conditions are met before setting up spektra domain:
```bash
kubectl wait pods -l app.kubernetes.io/instance=vault -n spektra-system --for condition=Initialized --timeout=0
```
pod/vault-0 condition met

```bash
kubectl wait pods -l app.kubernetes.io/instance=spektra-ingress -n spektra-system --for condition=Ready --timeout=0
```
pod/spektra-ingress-ingress-nginx-controller-647d97c54b-skbrs condition met 

```bash
kubectl wait pods -l statefulset.kubernetes.io/pod-name=catalog-mongo-0 -n spektra-system --for condition=Ready --timeout=0
```
pod/catalog-mongo-0 condition met

```bash
kubectl wait pods -l control-plane=controller-manager -n spektra-system --for condition=Ready --timeout=0
```
pod/capdi-controller-manager-b88bcd75b-nvtvl condition met \
pod/capi-attacher-controller-manager-686f6f5559-wdvtz condition met \
pod/capi-controller-manager-5f5775cb48-trccx condition met \
pod/capi-kubeadm-bootstrap-controller-manager-7d99996ff6-vwlqt condition met \
pod/capi-kubeadm-control-plane-controller-manager-565fb56c6f-tnr6k condition met \
pod/tenant-controller-manager-6c56dbdc86-r2z6k condition met

```bash
kubectl wait pods -l control-plane=upgrade-manager -n spektra-system --for condition=Ready --timeout=0
```
pod/upgrade-manager-7868d69f4b-8zvsg condition met

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
gcloud dns record-sets create <Spektra-FQDN> --rrdatas=<Spektra-Ingress-IP-Address> --type=A --ttl=60 --zone=zone-name
```
- Open the spektra URL: **https://&lt;fqdn&gt;:5443** and configure the Domain.
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
```
pod/vault-0 condition met

```bash
kubectl wait pods -l statefulset.kubernetes.io/pod-name=spektra-minio-pool-0-0 -n spektra-system --for condition=Ready --timeout=0
```
pod/spektra-minio-pool-0-0 condition met

```bash
kubectl wait pods -l app.kubernetes.io/name=query -n spektra-system --for condition=Ready --timeout=0
```
pod/spektra-thanos-query-6dd9c57795-bq7cz condition met

```bash
kubectl wait pods -l monitoring.banzaicloud.io/storeendpoint=spektra-thanos -n spektra-system --for condition=Ready --timeout=0
```
pod/spektra-thanos-spektra-thanos-store-5569d45cf-7mkxs condition met

```bash
kubectl wait pods -l statefulset.kubernetes.io/pod-name=spektra-thanos-receiver-soft-tenant-0 -n spektra-system --for condition=Ready --timeout=0
```
pod/spektra-thanos-receiver-soft-tenant-0 condition met

```bash
kubectl wait pods -l statefulset.kubernetes.io/pod-name=spektra-thanos-receiver-soft-tenant-1 -n spektra-system --for condition=Ready --timeout=0
```
pod/spektra-thanos-receiver-soft-tenant-1 condition met
