# Commands for setting up required resources in Azure and AKS
# Update the variables for your environment.
# To run lines individually in a PowerShell integrated termainal
# in VS Code, place the cursor on the line and press F8.

$resourceGroup = ""
$location =      "EastUS"
$aksName =       ""
$acrName =       ""
$keyVaultName =  ""
$imageName =     ""
# Azure Active Directory app registration client id and secret for authenticating to Key Vault
$clientID =      ""
$clientSecret =  ""
# Windows node settings
$winUser = ""
$winPwd = ""
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
    --generate-ssh-keys `
    --windows-admin-username "$winUser" `
    --windows-admin-password "$winPwd" `
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

# Get credentials for kubectl
az aks get-credentials --resource-group "$resourceGroup" --name "$aksName"

# Docker build
docker build --rm --pull -f Dockerfile -t $imageName .

# Docker run locally to test, browse to https://localhost:8443/
docker run --name aspnet-keyvault-test --rm -it -p 8000:80 -p 8443:443 -e "HTTPS_CERTIFICATE_PATH=.\certs\localhost.nopwd.pfx" $imageName

# Tag and push the image to the ACR
docker tag $imageName "$acrName.azurecr.io/$imageName"
docker push "$acrName.azurecr.io/$imageName"

# Key Vault: Allow our AAD app id registration access to the vault's secrets
az keyvault set-policy -n "$keyVaultName" --secret-permissions get --spn "$clientID"

# (import the PFX to Key Vault as per the README.md)

# Install the CSI secret driver and provider with Windows enabled
helm repo add csi-secrets-store-provider-azure https://azure.github.io/secrets-store-csi-driver-provider-azure/charts
helm install csi-secrets-store csi-secrets-store-provider-azure/csi-secrets-store-provider-azure --set windows.enabled=true --set secrets-store-csi-driver.windows.enabled=true --namespace kube-system

# Create the secret for Key Vault credentials
kubectl create secret generic kvcreds --from-literal "clientid=$clientID" --from-literal "clientsecret=$clientSecret"

# Create the deployment
kubectl apply -f k8s-aspnetapp-all-in-one.yaml

kubectl get pods,services

# stop or delete the cluster when done
az aks stop --name "$aksName" --resource-group "$resourceGroup"
az aks delete --name "$aksName" --resource-group "$resourceGroup" --yes --no-wait