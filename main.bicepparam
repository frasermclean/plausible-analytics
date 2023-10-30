using 'main.bicep'

param workload = 'plausible-analytics'
param location = 'australiaeast'
param fileShares = [
  {
    name: 'postgres-data'
    quota: 32
    isReadOnly: false
  }
  {
    name: 'clickhouse-data'
    quota: 24
    isReadOnly: false
  }
  {
    name: 'clickhouse-config'
    quota: 1
    isReadOnly: true
  }
]

param containerRegistryName = 'snakebyte'
param containerRegistryResourceGroup = 'snakebyte-core-rg'
