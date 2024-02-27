#source .env.sh
#
#az network public-ip create -n "${LB_PUBLIC_IP}" \
#  -g "${AZURE_RESOURCE_GROUP}" \
#  --allocation-method Static --sku Standard
#az network vnet create -n "${LB_VNET}" \
#  -g "${AZURE_RESOURCE_GROUP}" \
#  --address-prefix 10.0.0.0/16 --subnet-name "${LB_SUBNET}" \
#  --subnet-prefix 10.0.0.0/24
#az network application-gateway create -n "${LB_GATEWAY}" \
#  -g "${AZURE_RESOURCE_GROUP}" --sku Standard_v2 --public-ip-address "${LB_PUBLIC_IP}" \
#  --vnet-name "${LB_VNET}" --subnet "${LB_SUBNET}" --priority 100
#
#export APP_GATEWAY_ID=$(az network application-gateway show \
#  -n "${LB_GATEWAY}" -g "${AZURE_RESOURCE_GROUP}" \
#  -o tsv --query "id")
#
#
#az aks enable-addons -n "${CLUSTER}" \
#  -g "${AZURE_RESOURCE_GROUP}" \
#  -a ingress-appgw --appgw-id "${APP_GATEWAY_ID}"
#
#
#export NODE_RESOURCE_GROUP=$(az aks show -n  "${CLUSTER}" \
#  -g "${AZURE_RESOURCE_GROUP}" -o tsv --query "nodeResourceGroup")
#echo "Node resource group ${NODE_RESOURCE_GROUP}"
#
#
#
##$(az network vnet list -g  "${NODE_RESOURCE_GROUP}" \
##    -o tsv --query "[0].name")
#echo "AKS_VNET_NAME ${AKS_VNET_NAME}"
#
#
#
## az network vnet show -n "${AKS_VNET_NAME}" -g "${AKS_RESOURCE_GROUP}" -o tsv --query "id"
#
#export AZURE_RESOURCE_GROUP=xrc360v2
#export AZURE_DEFAULTS_LOCATION=eastus2
#export CLUSTER=XRC360V2-AKS-CLUSTER
#export EMAIL_ADDRESS=richardhightower@gmail.com
#export AZURE_SUBSCRIPTION_ID=Hightower
#export SERVICE_PRINCIPAL=xrc360v2SP
#export LB_SUBNET=xrc360v2_LBSubnet
#export LB_PUBLIC_IP=xrc360v2_LBPublicIP
#export LB_GATEWAY=xrc360v2_LBGateway
#export LB_VNET=xrc360v2_LBVNet
#
#export AKS_VNET_NAME=XRC360V2-VNET
#export AKS_RESOURCE_GROUP=MC_xrc360v2_XRC360V2-AKS-CLUSTER_eastus
#export AKS_VNET_ID=d43436fd-6ee7-4f7b-b2ed-4660f07104f0
#
#az network vnet peering create -n AppGWtoAKSVnetPeering \
#  -g "${AZURE_RESOURCE_GROUP}" --vnet-name "${LB_VNET}" \
#  --remote-vnet "${AKS_VNET_ID}" --allow-vnet-access
#

# Get application gateway id from AKS addon profile
appGatewayId=$(az aks show -n myCluster -g myResourceGroup -o tsv --query "addonProfiles.ingressApplicationGateway.config.effectiveApplicationGatewayId")

# Get Application Gateway subnet id
appGatewaySubnetId=$(az network application-gateway show --ids $appGatewayId -o tsv --query "gatewayIPConfigurations[0].subnet.id")

# Get AGIC addon identity
agicAddonIdentity=$(az aks show -n myCluster -g myResourceGroup -o tsv --query "addonProfiles.ingressApplicationGateway.identity.clientId")

# Assign network contributor role to AGIC addon identity to subnet that contains the Application Gateway
az role assignment create --assignee $agicAddonIdentity --scope $appGatewaySubnetId --role "Network Contributor"

kubectl apply -f https://raw.githubusercontent.com/Azure/application-gateway-kubernetes-ingress/master/docs/examples/aspnetapp.yaml

kubectl get ingress

NAME        CLASS                       HOSTS   ADDRESS          PORTS   AGE
aspnetapp   azure-application-gateway   *       20.161.173.104   80      18m

kubectl get service
NAME         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
aspnetapp    ClusterIP   10.0.255.176   <none>        80/TCP    19m
kubernetes   ClusterIP   10.0.0.1       <none>        443/TCP   27m

