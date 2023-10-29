targetScope = 'resourceGroup'

@description('Name of the Azure Container Registry')
param containerRegistryName string

param containerDefinitions array

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: containerRegistryName

  resource cacheRules 'cacheRules' = [for definition in containerDefinitions: {
    name: '${replace(definition.imageName, '/', '-')}-cache'
    properties: {
      sourceRepository: 'docker.io/${definition.imageName}'
      targetRepository: definition.imageName
    }
  }]
}

@description('The login server of the Azure Container Registry')
output registryLoginServer string = containerRegistry.properties.loginServer
