metadata description = 'Provisions resources for a web application that uses Azure SDK for Node.js to connect to Azure Cosmos DB for MongoDB.'

targetScope = 'resourceGroup'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention.')
param environmentName string

@minLength(1)
@description('Primary location for all resources.')
param location string

@description('(Optional) Principal identifier of the identity that is deploying the template.')
param azureDeploymentPrincipalId string = ''

var deploymentIdentityPrincipalId = !empty(azureDeploymentPrincipalId)
  ? azureDeploymentPrincipalId
  : deployer().objectId

@allowed([
  'vcore'
  'request-unit'
])
@description('Deployment type for the Azure Cosmos DB for MongoDB account. Defaults to Azure Cosmos DB for MongoDB vCore.')
param deploymentType string = 'request-unit'

// serviceName is used as value for the tag (azd-service-name) azd uses to identify deployment host
param typeScriptServiceName string = 'typescript-web'
param javaScriptServiceName string = 'javascript-web'

var resourceToken = toLower(uniqueString(resourceGroup().id, environmentName, location))
var tags = {
  'azd-env-name': environmentName
  repo: 'https://github.com/azure-samples/cosmos-db-mongodb-nodejs-quickstart'
}

module managedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: 'user-assigned-identity'
  params: {
    name: 'managed-identity-${resourceToken}'
    location: location
    tags: tags
  }
}

module keyVault 'br/public:avm/res/key-vault/vault:0.12.1' = {
  name: 'key-vault'
  params: {
    name: 'key-vault-${resourceToken}'
    location: location
    tags: tags
    enablePurgeProtection: false
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
    softDeleteRetentionInDays: 7
    roleAssignments: [
      {
        principalId: managedIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
      }
      {
        principalId: deploymentIdentityPrincipalId
        principalType: 'User'
        roleDefinitionIdOrName: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7' // Key Vault Secrets Officer
      }
    ]
    secrets: (deploymentType == 'vcore')
      ? [
          {
            name: 'azure-cosmos-db-mongodb-connection-string'
            value: replace(
              replace(cosmosDbAccountVCore.outputs.connectionStringKey, '<user>', 'app'),
              '<password>',
              'P0ssw.rd'
            )
          }
        ]
      : []
  }
}

module cosmosDbAccountVCore 'br/public:avm/res/document-db/mongo-cluster:0.1.1' = if (deploymentType == 'vcore') {
  name: 'cosmos-db-account-vcore'
  params: {
    name: 'cosmos-db-mongodb-vcore-${resourceToken}'
    location: location
    tags: tags
    nodeCount: 1
    sku: 'M10'
    highAvailabilityMode: false
    storage: 32
    administratorLogin: 'app'
    administratorLoginPassword: 'P0ssw.rd'
    networkAcls: {
      allowAllIPs: true
      allowAzureIPs: true
    }
  }
}

module cosmosDbAccountRequestUnit 'br/public:avm/res/document-db/database-account:0.11.3' = if (deploymentType == 'request-unit') {
  name: 'cosmos-db-account-ru'
  params: {
    name: 'cosmos-db-mongodb-ru-${resourceToken}'
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
      primaryWriteConnectionStringSecretName: 'azure-cosmos-db-mongodb-connection-string'
      keyVaultResourceId: keyVault.outputs.resourceId
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

module containerRegistry 'br/public:avm/res/container-registry/registry:0.9.1' = {
  name: 'container-registry'
  params: {
    name: 'containerreg${resourceToken}'
    location: location
    tags: tags
    acrAdminUserEnabled: false
    anonymousPullEnabled: false
    publicNetworkAccess: 'Enabled'
    acrSku: 'Standard'
    roleAssignments: [
      {
        principalId: managedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'AcrPull'
      }
      {
        principalId: deploymentIdentityPrincipalId
        roleDefinitionIdOrName: '8311e382-0749-4cb8-b61a-304f252e45ec' // AcrPush
      }
    ]
  }
}

module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.11.1' = {
  name: 'log-analytics-workspace'
  params: {
    name: 'log-analytics-${resourceToken}'
    location: location
    tags: tags
  }
}

module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.10.1' = {
  name: 'container-apps-env'
  params: {
    name: 'container-env-${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
    publicNetworkAccess: 'Enabled'
    zoneRedundant: false
  }
}

module containerAppsJsApp 'br/public:avm/res/app/container-app:0.14.1' = {
  name: 'container-apps-app-js'
  params: {
    name: 'container-app-js-${resourceToken}'
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': javaScriptServiceName })
    ingressTargetPort: 3000
    ingressExternal: true
    ingressTransport: 'auto'
    stickySessionsAffinity: 'sticky'
    scaleSettings: {
      minReplicas: 1
      maxReplicas: 1
    }
    corsPolicy: {
      allowCredentials: true
      allowedOrigins: [
        '*'
      ]
    }
    managedIdentities: {
      systemAssigned: false
      userAssignedResourceIds: [
        managedIdentity.outputs.resourceId
      ]
    }
    registries: [
      {
        server: containerRegistry.outputs.loginServer
        identity: managedIdentity.outputs.resourceId
      }
    ]
    secrets: [
      {
        name: 'azure-cosmos-db-mongodb-connection-string'
        keyVaultUrl: '${keyVault.outputs.uri}secrets/azure-cosmos-db-mongodb-connection-string'
        identity: managedIdentity.outputs.resourceId
      }
    ]
    containers: [
      {
        image: 'mcr.microsoft.com/dotnet/samples:aspnetapp-9.0'
        name: 'web-front-end'
        resources: {
          cpu: '0.25'
          memory: '.5Gi'
        }
        env: [
          {
            name: 'ASPNETCORE_HTTP_PORTS'
            value: '3000'
          }
          {
            name: 'CONFIGURATION__AZURECOSMOSDB__CONNECTIONSTRING'
            secretRef: 'azure-cosmos-db-mongodb-connection-string'
          }
          {
            name: 'CONFIGURATION__AZURECOSMOSDB__DATABASENAME'
            value: 'cosmicworks'
          }
          {
            name: 'CONFIGURATION__AZURECOSMOSDB__COLLECTIONNAME'
            value: 'products'
          }
        ]
      }
    ]
  }
}

module containerAppsTsApp 'br/public:avm/res/app/container-app:0.14.1' = {
  name: 'container-apps-app-ts'
  params: {
    name: 'container-app-ts-${resourceToken}'
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': typeScriptServiceName })
    ingressTargetPort: 3000
    ingressExternal: true
    ingressTransport: 'auto'
    stickySessionsAffinity: 'sticky'
    scaleSettings: {
      minReplicas: 1
      maxReplicas: 1
    }
    corsPolicy: {
      allowCredentials: true
      allowedOrigins: [
        '*'
      ]
    }
    managedIdentities: {
      systemAssigned: false
      userAssignedResourceIds: [
        managedIdentity.outputs.resourceId
      ]
    }
    registries: [
      {
        server: containerRegistry.outputs.loginServer
        identity: managedIdentity.outputs.resourceId
      }
    ]
    secrets: [
      {
        name: 'azure-cosmos-db-mongodb-connection-string'
        keyVaultUrl: '${keyVault.outputs.uri}secrets/azure-cosmos-db-mongodb-connection-string'
        identity: managedIdentity.outputs.resourceId
      }
    ]
    containers: [
      {
        image: 'mcr.microsoft.com/dotnet/samples:aspnetapp-9.0'
        name: 'web-front-end'
        resources: {
          cpu: '0.25'
          memory: '.5Gi'
        }
        env: [
          {
            name: 'ASPNETCORE_HTTP_PORTS'
            value: '3000'
          }
          {
            name: 'CONFIGURATION__AZURECOSMOSDB__CONNECTIONSTRING'
            secretRef: 'azure-cosmos-db-mongodb-connection-string'
          }
          {
            name: 'CONFIGURATION__AZURECOSMOSDB__DATABASENAME'
            value: 'cosmicworks'
          }
          {
            name: 'CONFIGURATION__AZURECOSMOSDB__COLLECTIONNAME'
            value: 'products'
          }
        ]
      }
    ]
  }
}

// Azure Container Registry outputs
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
