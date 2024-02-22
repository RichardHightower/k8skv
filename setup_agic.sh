# source .env.sh

#export SP_APP_ID=bfd1de40-2f5f-488b-9a59-1e720aedabac
#export SP_PWD=vSG8Q~85MYwARRVZVICi7dfcLGWtwcibcpLBKc~b
#export SP_TENANT_ID=1aad45ce-4bcd-472a-aea5-60fdbd500a7d
#   --set armAuth.secret=${SERVICE_PRINCIPAL} \
#  --set armAuth.clientId=${SP_APP_ID} \
#  --set armAuth.clientSecret=${SP_PWD} \
#  --set armAuth.tenantId=${SP_TENANT_ID} \
# --set-file armAuth.secretJSON=sp_secret.json \
  #


helm install agic application-gateway-kubernetes-ingress/ingress-azure \
  --namespace kube-system \
  --values values.yaml \
  --set appgw.subscriptionId=${AZURE_SUBSCRIPTION_ID} \
  --set appgw.resourceGroup=${AZURE_DEFAULTS_GROUP} \
  --set appgw.name=${AZURE_LOADBALANCER_DNS_LABEL_NAME} \
  --set armAuth.type=servicePrincipal \
  --set rbac.enabled=true
