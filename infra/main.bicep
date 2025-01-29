metadata description = 'Provisions resources for a web application that uses Azure SDK for Node.js to connect to Azure Cosmos DB for MongoDB.'

targetScope = 'resourceGroup'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention.')
param environmentName string

@minLength(1)
@description('Primary location for all resources.')
param location string

@description('Id of the principal to assign database and application roles.')
param deploymentUserPrincipalId string = ''

@allowed([
  'vcore'
  'request-unit'
])
@description('Deployment type for the Azure Cosmos DB for MongoDB account. Defaults to Azure Cosmos DB for MongoDB vCore.')
param deploymentType string = 'vcore'

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

module keyVault 'br/public:avm/res/key-vault/vault:0.11.2' = {
  name: 'key-vault'
  params: {
    name: 'key-vault-${resourceToken}'
    location: location
    tags: tags
    enablePurgeProtection: false
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
    softDeleteRetentionInDays: 7
    roleAssignments: union(
      [
        {
          principalId: managedIdentity.outputs.principalId
          principalType: 'ServicePrincipal'
          roleDefinitionIdOrName: '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
        }
      ],
      !empty(deploymentUserPrincipalId)
        ? [
            {
              principalId: deploymentUserPrincipalId
              principalType: 'User'
              roleDefinitionIdOrName: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7' // Key Vault Secrets Officer
            }
          ]
        : []
    )
  }
}

module cosmosDbAccount 'app/database.bicep' = {
  name: 'cosmos-db-account'
  params: {
    vCoreAccountName: 'cosmos-db-mongodb-vcore-${resourceToken}'
    requestUnitAccountName: 'cosmos-db-mongodb-ru-${resourceToken}'
    location: location
    tags: tags
    deploymentType: deploymentType
    keyVaultResourceId: keyVault.outputs.resourceId
  }
}

module containerRegistry 'br/public:avm/res/container-registry/registry:0.8.0' = {
  name: 'container-registry'
  params: {
    name: 'containerreg${resourceToken}'
    location: location
    tags: tags
    acrAdminUserEnabled: false
    anonymousPullEnabled: false
    publicNetworkAccess: 'Enabled'
    acrSku: 'Standard'
    cacheRules: [
      {
        name: 'mcr-cache-rule'
        sourceRepository: 'mcr.microsoft.com/*'
        targetRepository: 'mcr/*'
      }
    ]
    roleAssignments: [
      {
        principalId: managedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'AcrPull'
      }
    ]
  }
}

module registryUserPushAssignment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = if (!empty(deploymentUserPrincipalId)) {
  name: 'container-registry-role-assignment-push-user'
  params: {
    principalId: deploymentUserPrincipalId
    resourceId: containerRegistry.outputs.resourceId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '8311e382-0749-4cb8-b61a-304f252e45ec'
    ) // AcrPush built-in role
  }
}

module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.9.1' = {
  name: 'log-analytics-workspace'
  params: {
    name: 'log-analytics-${resourceToken}'
    location: location
    tags: tags
  }
}

module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.8.2' = {
  name: 'container-apps-env'
  params: {
    name: 'container-env-${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
    zoneRedundant: false
  }
}

module containerAppsJsApp 'br/public:avm/res/app/container-app:0.12.1' = {
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
    scaleMaxReplicas: 1
    scaleMinReplicas: 1
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
    secrets: {
      secureList: [
        {
          name: 'azure-cosmos-db-mongodb-connection-string'
          keyVaultUrl: '${keyVault.outputs.uri}secrets/${cosmosDbAccount.outputs.keyVaultSecretName}'
          identity: managedIdentity.outputs.resourceId
        }
        {
          name: 'azure-cosmos-db-mongodb-admin-password'
          value: cosmosDbAccount.outputs.cosmosDbAccountVCoreKey
        }
      ]
    }
    containers: [
      {
        image: '${containerRegistry.outputs.loginServer}/mcr/dotnet/samples:aspnetapp-9.0'
        name: 'web-front-end'
        resources: {
          cpu: '0.25'
          memory: '.5Gi'
        }
        env: [
          {
            name: 'CONFIGURATION__AZURECOSMOSDB__CONNECTIONSTRING'
            secretRef: 'azure-cosmos-db-mongodb-connection-string'
          }
          {
            name: 'CONFIGURATION__AZURECOSMOSDB__ADMINLOGIN'
            value: 'app'
          }
          {
            name: 'CONFIGURATION__AZURECOSMOSDB__ADMINPASSWORD'
            secretRef: 'azure-cosmos-db-mongodb-admin-password'
          }
          {
            name: 'CONFIGURATION__AZURECOSMOSDB__DATABASENAME'
            value: 'cosmicworks'
          }
          {
            name: 'CONFIGURATION__AZURECOSMOSDB__COLLECTIONNAME'
            value: 'products'
          }
          {
            name: 'ASPNETCORE_HTTP_PORTS'
            value: '3000'
          }
        ]
      }
    ]
  }
}

module containerAppsTsApp 'br/public:avm/res/app/container-app:0.12.1' = {
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
    scaleMaxReplicas: 1
    scaleMinReplicas: 1
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
    secrets: {
      secureList: [
        {
          name: 'azure-cosmos-db-mongodb-connection-string'
          keyVaultUrl: '${keyVault.outputs.uri}secrets/${cosmosDbAccount.outputs.keyVaultSecretName}'
          identity: managedIdentity.outputs.resourceId
        }
        {
          name: 'azure-cosmos-db-mongodb-admin-password'
          value: cosmosDbAccount.outputs.cosmosDbAccountVCoreKey
        }
      ]
    }
    containers: [
      {
        image: '${containerRegistry.outputs.loginServer}/mcr/dotnet/samples:aspnetapp-9.0'
        name: 'web-front-end'
        resources: {
          cpu: '0.25'
          memory: '.5Gi'
        }
        env: [
          {
            name: 'CONFIGURATION__AZURECOSMOSDB__CONNECTIONSTRING'
            secretRef: 'azure-cosmos-db-mongodb-connection-string'
          }
          {
            name: 'CONFIGURATION__AZURECOSMOSDB__ADMINLOGIN'
            value: 'app'
          }
          {
            name: 'CONFIGURATION__AZURECOSMOSDB__ADMINPASSWORD'
            secretRef: 'azure-cosmos-db-mongodb-admin-password'
          }
          {
            name: 'CONFIGURATION__AZURECOSMOSDB__DATABASENAME'
            value: 'cosmicworks'
          }
          {
            name: 'CONFIGURATION__AZURECOSMOSDB__COLLECTIONNAME'
            value: 'products'
          }
          {
            name: 'ASPNETCORE_HTTP_PORTS'
            value: '3000'
          }
        ]
      }
    ]
  }
}

// Azure Container Registry outputs
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
