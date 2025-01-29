metadata description = 'Creates Azure Cosmos DB for MongoDB account resources.'

param requestUnitAccountName string
param vCoreAccountName string
param tags object = {}

@description('Location for the Cosmos DB account.')
param location string = resourceGroup().location

@allowed([
  'vcore'
  'request-unit'
])
@description('Deployment type for the Azure Cosmos DB for MongoDB account. Defaults to Azure Cosmos DB for MongoDB vCore.')
param deploymentType string

@description('Resource identifier for an Azure Key Vault instance.')
param keyVaultResourceId string

var keyVaultSecretName = 'azure-cosmos-db-mongodb-connection-string'

module cosmosDbAccountVCore 'br/public:avm/res/document-db/mongo-cluster:0.1.1' = if (deploymentType == 'vcore') {
  name: 'cosmos-db-account-vcore'
  params: {
    name: vCoreAccountName
    location: location
    tags: tags
    nodeCount: 1
    sku: 'Free'
    highAvailabilityMode: false
    storage: 32
    administratorLogin: 'app'
    administratorLoginPassword: 'P0ssw.rd'
    networkAcls: {
      allowAllIPs: true
      allowAzureIPs: true
    }
    secretsExportConfiguration: {
      connectionStringSecretName: keyVaultSecretName
      keyVaultResourceId: keyVaultResourceId
    }
  }
}

module cosmosDbAccountRequestUnit 'br/public:avm/res/document-db/database-account:0.10.2' = if (deploymentType == 'request-unit') {
  name: 'cosmos-db-account-ru'
  params: {
    name: requestUnitAccountName
    location: location
    locations: [
      {
        failoverPriority: 0
        locationName: location
        isZoneRedundant: false
      }
    ]
    tags: tags
    disableKeyBasedMetadataWriteAccess: false
    disableLocalAuth: false
    networkRestrictions: {
      publicNetworkAccess: 'Enabled'
      ipRules: []
      virtualNetworkRules: []
    }
    capabilitiesToAdd: [
      'EnableServerless'
    ]
    secretsExportConfiguration: {
      primaryWriteConnectionStringSecretName: keyVaultSecretName
      keyVaultResourceId: keyVaultResourceId
    }
    mongodbDatabases: [
      {
        name: 'cosmicworks'
        collections: [
          {
            name: 'products'
            indexes: [
              {
                key: {
                  keys: [
                    '_id'
                  ]
                }
              }
              {
                key: {
                  keys: [
                    '$**'
                  ]
                }
              }
              {
                key: {
                  keys: [
                    '_ts'
                  ]
                }
                options: {
                  expireAfterSeconds: 2629746
                }
              }
            ]
            shardKey: {
              category: 'Hash'
            }
          }
        ]
      }
    ]
  }
}

output keyVaultSecretName string = keyVaultSecretName
output cosmosDbAccountVCoreKey string = deploymentType == 'vcore' ? 'P0ssw.rd' : ' '
