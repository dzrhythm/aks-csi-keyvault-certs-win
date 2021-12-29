# NOTE: The container's Windows Server version must be compatible with
# the Kubernetes node Windows Server version. Reference:
# https://docs.microsoft.com/virtualization/windowscontainers/deploy-containers/version-compatibility

FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-ltsc2019 AS build
WORKDIR /app

# copy csproj and restore as distinct layers
COPY *.sln .
COPY aspnetmvcapp/*.csproj ./aspnetmvcapp/
COPY aspnetmvcapp/*.config ./aspnetmvcapp/
RUN nuget restore

# copy everything else and build app
COPY aspnetmvcapp/. ./aspnetmvcapp/
WORKDIR /app/aspnetmvcapp
RUN msbuild /p:Configuration=Release -r:False

FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2019 AS runtime
WORKDIR /inetpub/wwwroot
COPY --from=build /app/aspnetmvcapp/. ./

# Expose HTTPS port
EXPOSE 443

# This is for local container running/debugging and is not needed for AKS deployment
COPY ./certs ./certs

# Copy the IIS bootstrapping script and set as the entrypoint
COPY ./Bootstrap-IIS.ps1 ./
ENTRYPOINT ["powershell.exe", "./Bootstrap-IIS.ps1"]
