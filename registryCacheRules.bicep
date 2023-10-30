targetScope = 'resourceGroup'

@description('Name of the Azure Container Registry')
param containerRegistryName string

@description('Array of Docker Hub container images to cache in the Azure Container Registry')
param containerImages array

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: containerRegistryName

  resource cacheRules 'cacheRules' = [for image in containerImages: {
    name: '${replace(image, '/', '-')}-cache'
    properties: {
      sourceRepository: 'docker.io/${image}'
      targetRepository: image
    }
  }]
}

@description('The login server of the Azure Container Registry')
output registryLoginServer string = containerRegistry.properties.loginServer
