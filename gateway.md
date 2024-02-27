Turn these into a step-by-step tutorial and make sure this works. 
Look for errors and help me fix them. 
https://learn.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-existing

____

# Tutorial: Enable application gateway ingress controller add-on for an existing AKS cluster with an existing application gateway with TLS termination 

```bash 
az group create --name myResourceGroup --location eastus
```

```sh
az network vnet create -n aksVNet -g myResourceGroup \
  --address-prefix 10.0.0.0/16 --subnet-name mySubnet \
  --subnet-prefix 10.0.0.0/24 
  
 az aks create -n myCluster -g myResourceGroup \
  --network-plugin azure --enable-managed-identity \
  --service-cidr 10.2.0.0/16 \
  --dns-service-ip 10.2.0.10 \
  --generate-ssh-keys --vnet-subnet-id /subscriptions/a8e1aab4-eb7f-4ffb-87a1-4a8d0155dd32/resourceGroups/myResourceGroup/providers/Microsoft.Network/virtualNetworks/aksVNet/subnets/mySubnet

```

# Create TODO cert/certificate.pfx a self signed certificate 

```sh 
az network public-ip create -n myPublicIp -g myResourceGroup \
  --allocation-method Static --sku Standard
```  


```sh
az network application-gateway create \
 --name myApplicationGateway \
 --location eastus \
 --resource-group myResourceGroup \
 --capacity 2 \
 --sku Standard_v2 \
 --http-settings-cookie-based-affinity Disabled \
 --frontend-port 443 \
 --http-settings-port 80 \
 --http-settings-protocol Http \
 --public-ip-address MyPublicIP \
 --cert-file certificate.pfx \
 --cert-password peak6 \
 --priority 1
 
```

```bash 
appgwId=$(az network application-gateway show -n myApplicationGateway \
  -g myResourceGroup -o tsv --query "id") 
  
az aks enable-addons -n myCluster -g myResourceGroup \
  -a ingress-appgw --appgw-id $appgwId
```

[//]: # ()
[//]: # (```bash )

[//]: # (nodeResourceGroup=$&#40;az aks show -n myCluster -g myResourceGroup -o tsv --query "nodeResourceGroup"&#41;)

[//]: # (# aksVnetName=$&#40;az network vnet list -g $nodeResourceGroup -o tsv --query "[0].name"&#41;)

[//]: # (aksVnetName=aksVNet)

[//]: # ()
[//]: # (#aksVnetId=$&#40;az network vnet show -n $aksVnetName -g $nodeResourceGroup -o tsv --query "id"&#41;)

[//]: # (aksVnetId=6774b6d3-2395-47b8-8755-af085e686080)

[//]: # ()
[//]: # (az network vnet peering create -n AppGWtoAKSVnetPeering -g myResourceGroup --vnet-name myVnet --remote-vnet $aksVnetId --allow-vnet-access)

[//]: # ()
[//]: # (appGWVnetId=$&#40;az network vnet show -n myVnet -g myResourceGroup -o tsv --query "id"&#41;)

[//]: # (az network vnet peering create -n AKStoAppGWVnetPeering -g $nodeResourceGroup --vnet-name $aksVnetName --remote-vnet $appGWVnetId --allow-vnet-access)

[//]: # (```)

```bash 
az aks get-credentials -n myCluster -g myResourceGroup
```

```bash 
kubectl apply -f https://raw.githubusercontent.com/Azure/application-gateway-kubernetes-ingress/master/docs/examples/aspnetapp.yaml
```

```bash 
kubectl get ingress
NAME        CLASS                       HOSTS   ADDRESS          PORTS   AGE
aspnetapp   azure-application-gateway   *       20.161.173.104   443      18m

```
```bash 
kubectl get service
NAME         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
aspnetapp    ClusterIP   10.0.255.176   <none>        80/TCP    19m

```

TODO Make it so the following works 

```bash 
curl  https://20.161.173.104 
```



```sh
vnet1Id=$(az network vnet show -n aksVNet -g myResourceGroup --query id -o tsv)
vnet2Id=$(az network application-gateway show -n myApplicationGateway -g myResourceGroup --query "gatewayIPConfigurations[0].subnet.id" -o tsv)

```

```sh
az network vnet peering create --name aksToAppGW --resource-group myResourceGroup --vnet-name aksVNet --remote-vnet /subscriptions/a8e1aab4-eb7f-4ffb-87a1-4a8d0155dd32/resourceGroups/myResourceGroup/providers/Microsoft.Network/virtualNetworks/myApplicationGatewayVnet --allow-vnet-access

```
