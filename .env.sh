export AZURE_DEFAULTS_GROUP=xrc360v2
export AZURE_DEFAULTS_LOCATION=eastus2
export DOMAIN_NAME=xrc360.com
export CLUSTER=XRC360V2-AKS-CLUSTER
export AZURE_LOADBALANCER_DNS_LABEL_NAME=lb-cert-manager-demo
export USER_ASSIGNED_IDENTITY_NAME=cert-manager-xrc360
export USER_ASSIGNED_IDENTITY_CLIENT_ID=$(az identity show --name "${USER_ASSIGNED_IDENTITY_NAME}" --query 'clientId' -o tsv)
export SERVICE_ACCOUNT_NAME=cert-manager # ℹ️ This is the default Kubernetes ServiceAccount used by the cert-manager controller.
export SERVICE_ACCOUNT_NAMESPACE=cert-manager # ℹ️ This is the default namespace for cert-manager.
export SERVICE_ACCOUNT_ISSUER=$(az aks show --resource-group $AZURE_DEFAULTS_GROUP --name $CLUSTER --query "oidcIssuerProfile.issuerUrl" -o tsv)
export EMAIL_ADDRESS=richardhightower@gmail.com
export AZURE_SUBSCRIPTION_ID=Hightower
export SERVICE_PRINCIPAL=xrc360v2SP
# az ad sp create-for-rbac --name $SERVICE_PRINCIPAL
