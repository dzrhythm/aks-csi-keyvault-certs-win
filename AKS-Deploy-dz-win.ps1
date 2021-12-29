# Commands for setting up required resources in Azure and AKS
# Update the variables for your environment.
# To run lines individually in a PowerShell integrated termainal
# in VS Code, place the cursor on the line and press F8.

#[Environment]::SetEnvironmentVariable("HELM_EXPERIMENTAL_OCI", 1, [EnvironmentVariableTarget]::Process)

$resourceGroup = "aisdz-aks-win"
$location =      "EastUS"
$aksName =       "ais-dz-aks-win"
$acrName =       "aisdzcsicr"
$keyVaultName =  "ais-dz-k8s-vault"
$imageName =     "aspnet-keyvault-win"
# Azure Active Directory app registration client id and secret for authenticating to Key Vault
$clientID =      "2065926b-4730-40f3-9345-94af9698b03c"
$clientSecret =  "5bS-0LmE5m4iW_4tXrVl_Tz3_NEYltB50G"
# Windows node settings
$winUser = "dz"
$winPwd = "Thisismystrongpassword123!"
$winNodePool = "npwin"

az login

# Resource Group
az group create --name "$resourceGroup" --location "$location"

# Create and authenticate to the ACR
az acr create --resource-group "$resourceGroup" --name "$acrName" --sku Basic
az acr login --name "$acrName"

# Create the cluster
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

# Add a windows node pool
az aks nodepool add `
    --resource-group $resourceGroup `
    --cluster-name $aksName `
    --os-type Windows `
    --name $winNodePool `
    --node-count 1

# Get credeentials for kubectl
az aks get-credentials --resource-group "$resourceGroup" --name "$aksName"

# Docker build
docker build --rm --pull -f Dockerfile -t $imageName .

# Docker run locally to test
docker run --name aspnet_test --rm -it -p 8000:80 -p 8443:443 -e "HTTPS_CERTIFICATE_PATH=certs/locahost.pfx.base64" aspnet-keyvault-win

# Tag and push the image to the ACR
docker tag $imageName "$acrName.azurecr.io/$imageName"
docker push "$acrName.azurecr.io/$imageName"

# Key Vault
az keyvault set-policy -n "$keyVaultName" --secret-permissions get --spn "$clientID"

# (import the PFX to Key Vault as per the README.md)

# Install the CSI secret driver and provider with Windows enabled
helm repo add csi-secrets-store-provider-azure https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/charts
helm install csi-secrets-store-provider-azure/csi-secrets-store-provider-azure --generate-name --set windows.enabled=true --set=secrets-store-csi-driver.windows.enabled=true --namespace kube-system

# Create the secret for Key Vault credentials
kubectl create secret generic kvcreds --from-literal "clientid=$clientID" --from-literal "clientsecret=$clientSecret"

# Create the deployment
kubectl apply -f k8s-aspnetapp-all-in-one-dz-win.yaml

kubectl get pods,services

# delete the cluster when done
az aks delete --name "$aksName" --resource-group "$resourceGroup" --yes --no-wait