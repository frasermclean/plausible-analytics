using 'main.bicep'

param workload = 'plausible-analytics'
param location = 'australiaeast'
param fileShares = [
  {
    name: 'postgres-data'
    quota: 32
  }
  {
    name: 'clickhouse-data'
    quota: 24
  }
  {
    name: 'clickhouse-config'
    quota: 1
  }
]

param containerRegistryName = 'snakebyte'
param containerRegistryResourceGroup = 'snakebyte-core-rg'
param containerDefinitions = [
  {
    name: 'mail'
    imageName: 'bytemark/smtp'
    imageTag: 'latest'
    cpuCores: '0.25'
    memory: '0.5Gi'
  }
]
