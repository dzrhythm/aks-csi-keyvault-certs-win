# aks-csi-keyvault-certs-win

Sample for using Azure Key Vault for mounting certificates in  Windows containers running
in Azure Kubernetes Service, using the
[Kubernetes CSI Secret Store driver and provider for Azure](https://github.com/Azure/secrets-store-csi-driver-provider-azure).

The application source comes from the
[aspnetmvcapp](https://github.com/microsoft/dotnet-framework-docker/tree/main/samples/aspnetmvcapp) sample application in the
[Microsoft .NET Framework Docker repo](https://github.com/microsoft/dotnet-framework-docker).

This code is for demonstration purposes only and is not intended for production.

## Requirements

- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest)
- [Helm](https://helm.sh) 3 or later.
- A [Microsoft Azure account](https://azure.microsoft.com/free/).
- [Microsoft Visual Studio](https://visualstudio.microsoft.com/)
- Optional: [Visual Studio Code](https://code.visualstudio.com/) with the Docker and Kubernetes extensions.

## Deploying to AKS

These instructions assume you have basic knowledge about:

- building and pushing Docker images
- deploying simple applications to Azure Kubernetes Service.

See [AKS-Deploy.ps1](AKS-Deploy.ps1) for example Azure CLI commands
for most of these steps. To run this sample in AKS:

1. Create a self-signed private key certificate, or use the sample one included in this repo:
   [certs\localhost.pfx](certs\localhost.pfx).
   (Password: `abcdefghijklmnopqrstuvwxyz0123456789`).

2. Create an [Azure Key Vault](https://azure.microsoft.com/services/key-vault/)
   in your subscription.

3. Import the certificate into your Key Vault using the name "aks-https".

4. Create an [Azure Container Registry (ACR)](https://azure.microsoft.com/services/container-registry/).

5. Rember to switch Docker Desktop to Windows Containers. Build a Docker image of the app using the
   [Dockerfile](Dockerfile), then tag and push the image to your registry.

6. Create an [Azure Kubernetes Service (AKS)](https://azure.microsoft.com/services/kubernetes-service/)
   cluster attached to your ACR. Next create a Windows node pool.

7. Create an [app registration](https://docs.microsoft.com/azure/active-directory/develop/quickstart-register-app)
   in Azure Active Directory (AAD) to use as a service principal. Get the client ID,
   then generate and save a secret to use.

8. In your Key Vault, add an Access Policy to grant your service principal "Get"
   permissions for keys, secrets and certificates.

9. Edit the [k8s-aspnetapp-all-in-one.yaml](k8s-aspnetapp-all-in-one.yaml) file:
   - Update the `SecretProviderClass` section with the `tenantid` and `keyvaultname` of your Key Vault.
   - Update the `Deployment` section with the registry path to your Docker `image`.

10. In a terminal get credentials to your cluster with `az aks get-credentials`.

11. Deploy CSI Secret Store driver and provider for Azure to your cluster:

    `helm repo add csi-secrets-store-provider-azure https://azure.github.io/secrets-store-csi-driver-provider-azure/charts`

    `helm install csi-secrets-store-provider-azure/csi-secrets-store-provider-azure --generate-name --set windows.enabled=true --set=secrets-store-csi-driver.windows.enabled=true --namespace kube-system`

12. Using the AAD registration client id and secret, create a Kubernetes Secret Key Vault credentials, substituting your CLIENTID and CLIENTSECRET:

    `kubectl create secret generic kvcreds --from-literal clientid=<CLIENTID> --from-literal clientsecret=<CLIENTSECRET>`

13. Apply the application YAML:

    `kubectl apply -f k8s-aspnetapp-all-in-one.yaml`

14. Make sure the pod is running:

    `kubectl get pods`

15. List the service:

    `kubectl get service aks-keyvault-aspnetcore-svc`

    Get the EXTERNAL-IP and browse to it using `https://YOUR-IP`
    (you will probably need to bypass the warning about the self-signed cert).

## Notes

The [certs](certs) folder has self-signed localhost certificates for
development and testing. Of course these are not meant for production use :-).
