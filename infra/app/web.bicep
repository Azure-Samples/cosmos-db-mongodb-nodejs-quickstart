metadata description = 'Create web application resources.'

param envName string
param appName string
param serviceTag string
param location string = resourceGroup().location
param tags object = {}
param keyVaultEndpoint string

@description('Endpoint for Azure Cosmos DB for NoSQL account.')
param databaseAccountEndpoint string

type managedIdentity = {
  resourceId: string
  clientId: string
}

@description('Unique identifier for user-assigned managed identity.')
param userAssignedManagedIdentity managedIdentity

@description('Unique identifier for user-assigned managed identity.')
param cosmosconnectionstring string

module containerAppsEnvironment '../core/host/container-apps/environments/managed.bicep' = {
  name: 'container-apps-env'
  params: {
    name: envName
    location: location
    tags: tags
  }
}

module containerAppsApp '../core/host/container-apps/app.bicep' = {
  name: 'container-apps-app'
  params: {
    name: appName
    parentEnvironmentName: containerAppsEnvironment.outputs.name
    location: location
    tags: union(tags, {
        'azd-service-name': serviceTag
      })
    secrets: [
      {
        name: 'azure-cosmos-db-mongo-endpoint' // Create a uniquely-named secret
        value: databaseAccountEndpoint // NoSQL database account endpoint
      }
      {
        name: 'azure-managed-identity-client-id' // Create a uniquely-named secret
        value: userAssignedManagedIdentity.clientId // Client ID of user-assigned managed identity
      }
      {
        name: 'keyvault-endpoint' // Create a uniquely-named secret
        value: keyVaultEndpoint // Client ID of user-assigned managed identity
      }
      {
        name: 'azure-client-id' // Create a uniquely-named secret
        value: userAssignedManagedIdentity.clientId // Client ID of user-assigned managed identity
      }
      {
        name: 'cosmos-connection-string' // Create a uniquely-named secret
        value: cosmosconnectionstring // Client ID of user-assigned managed identity
      }
    ]
    environmentVariables: [
      {
        name: 'AZURE_COSMOS_DB_MONGO_ENDPOINT' // Name of the environment variable referenced in the application
        secretRef: 'azure-cosmos-db-mongo-endpoint' // Reference to secret
      }
      {
        name: 'AZURE_MANAGED_IDENTITY_CLIENT_ID'
        secretRef: 'azure-managed-identity-client-id'
      }
      {
        name: 'KEYVAULT_ENDPOINT'
        secretRef: 'keyvault-endpoint'
      }
      {
        name: 'AZURE_CLIENT_ID'
        secretRef: 'azure-client-id'
      }
      {
        name: 'COSMOS_CONNECTION_STRING'
        secretRef: 'cosmos-connection-string'
      }
    ]
    targetPort: 3000
    enableSystemAssignedManagedIdentity: false
    userAssignedManagedIdentityIds: [
      userAssignedManagedIdentity.resourceId
    ]
  }
}

output endpoint string = containerAppsApp.outputs.endpoint
output envName string = containerAppsApp.outputs.name
