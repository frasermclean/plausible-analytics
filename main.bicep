targetScope = 'resourceGroup'

@description('Name of the workload')
param workload string

@description('Location for resources within the resource group')
param location string = resourceGroup().location

@description('Array of file shares to create in the storage account')
param fileShares array

var tags = {
  workload: workload
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
        accessMode: 'ReadWrite'
        accountKey: storageAccount.listKeys().keys[0].value
        accountName: storageAccount.name
        shareName: share.name
      }
    }
  }]
}
