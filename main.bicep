targetScope = 'resourceGroup'

@description('Name of the workload')
param workload string

@description('Location for resources within the resource group')
param location string = resourceGroup().location

@description('Array of file shares to create in the storage account')
param fileShares array

@description('Name of the container registry')
param containerRegistryName string

@description('Container registry resource group')
param containerRegistryResourceGroup string

var tags = {
  workload: workload
}

module registryCacheRules 'registryCacheRules.bicep' = {
  name: 'registryCacheRules-${workload}'
  scope: resourceGroup(containerRegistryResourceGroup)
  params: {
    containerRegistryName: containerRegistryName
    containerImages: [
      'bytemark/smtp'
      'library/postgres'
    ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: replace(workload, '-', '')
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }

  resource fileServices 'fileServices' = {
    name: 'default'
    properties: {
      protocolSettings: {
        smb: { // apply maximum security settings
          authenticationMethods: 'Kerberos'
          channelEncryption: 'AES-256-GCM'
          kerberosTicketEncryption: 'AES-256'
          versions: 'SMB3.1.1'
        }
      }
    }

    resource share 'shares' = [for share in fileShares: {
      name: share.name
      properties: {
        shareQuota: share.quota
      }
    }]
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${workload}-law'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${workload}-id'
  location: location
  tags: tags
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: '${workload}-cae'
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }

  resource storage 'storages' = [for share in fileShares: {
    name: share.name
    properties: {
      azureFile: {
        accessMode: share.isReadOnly ? 'ReadOnly' : 'ReadWrite'
        accountKey: storageAccount.listKeys().keys[0].value
        accountName: storageAccount.name
        shareName: share.name
      }
    }
  }]
}

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${workload}-ca'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    environmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8000
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: registryCacheRules.outputs.registryLoginServer
          identity: managedIdentity.id
        }
      ]
      secrets: [
        {
          name: 'postgres-password'
          value: uniqueString(resourceGroup().id)
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'mail'
          image: '${registryCacheRules.outputs.registryLoginServer}/bytemark/smtp:latest'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
        {
          name: 'main-db'
          image: '${registryCacheRules.outputs.registryLoginServer}/library/postgres:14-alpine'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'POSTGRES_PASSWORD'
              secretRef: 'postgres-password'
            }
          ]
          volumeMounts: [
            {
              volumeName: 'postgres-data'
              mountPath: '/var/lib/postgresql/data'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
      volumes: [for share in fileShares: {
        name: share.name
        storageName: share.name
        storageType: 'AzureFile'
      }]
    }
  }
}
