# Commands for setting up required resources in Azure and AKS
# Update the variables for your environment.
# To run lines individually in a PowerShell integrated termainal
# in VS Code, place the cursor on the line and press F8.

[Environment]::SetEnvironmentVariable("HELM_EXPERIMENTAL_OCI", 1, [EnvironmentVariableTarget]::Process)

$resourceGroup = "aisdz-aks-win"
$location =      "EastUS"
$aksName =       "ais-dz-aks-win"
$acrName =       "aisdzcsicr"
$keyVaultName =  "ais-dz-k8s-vault"
# Azure Active Directory app registration client id and secret for authenticating to Key Vault
$clientID =      "2065926b-4730-40f3-9345-94af9698b03c"
$clientSecret =  "5bS-0LmE5m4iW_4tXrVl_Tz3_NEYltB50G"
$winUser = "dz"
$winPwd = "Thisismystrongpassword123!"
$winNodePool = "npwin"

az login

# Resource Group
az group create --name "$resourceGroup" --location "$location"

az aks create `
    --resource-group $resourceGroup `
    --name $aksName `
    --node-count 2 `
    --enable-addons monitoring `
    --generate-ssh-keys `
    --windows-admin-username $winUser `
    --windows-admin-password $winPwd `
    --vm-set-type VirtualMachineScaleSets `
    --network-plugin azure `
    --attach-acr "$acrName"

az aks nodepool add `
    --resource-group $resourceGroup `
    --cluster-name $aksName `
    --os-type Windows `
    --name $winNodePool `
    --node-count 1

# ACR
az acr create --resource-group "$resourceGroup" --name "$acrName" --sku Basic
az acr login --name "$acrName"

# Docker build
docker build --rm --pull -f Dockerfile.win -t aspnet-keyvault-win .

# Tag and push the image to the ACR
docker tag aspnet-keyvault-win "$acrName.azurecr.io/aspnet-keyvault-win"
docker push "$acrName.azurecr.io/aspnet-keyvault-win"

# Key Vault
az keyvault set-policy -n "$keyVaultName" --secret-permissions get --spn "$clientID"

# (import the PFX as per the README.md)

# AKS
#az aks create --resource-group "$resourceGroup" --name "$aksName" --node-count 2 --generate-ssh-keys --attach-acr "$acrName"
az aks get-credentials --resource-group "$resourceGroup" --name "$aksName"

# Install the CSI secret driver and provider
helm repo add csi-secrets-store-provider-azure https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/charts
helm install csi-secrets-store-provider-azure/csi-secrets-store-provider-azure --generate-name --set windows.enabled=true --set=secrets-store-csi-driver.windows.enabled=true

# Create the secret for Key Vault credentials
kubectl create secret generic kvcreds --from-literal "clientid=$clientID" --from-literal "clientsecret=$clientSecret"

# Create the deployment
kubectl apply -f k8s-aspnetapp-all-in-one-dz-win.yaml

kubectl get pods
kubectl get services

# delete the cluster when done
az aks delete --name "$aksName" --resource-group "$resourceGroup" --yes --no-wait