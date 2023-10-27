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
