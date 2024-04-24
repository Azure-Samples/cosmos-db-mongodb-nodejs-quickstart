targetScope = 'subscription'

// The main bicep module to provision Azure resources.
// For a more complete walkthrough to understand how this file works with azd,
// see https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/make-azd-compatible?pivots=azd-create

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Id of the principal to assign database and application roles.')
param principalId string = ''

// Optional parameters to override the default azd resource naming conventions.
// Add the following to main.parameters.json to provide values:
// "resourceGroupName": {
//      "value": "myGroupName"
// }
param resourceGroupName string = ''
// Optional parameters
param cosmosAccountName string = ''
param cosmosDatabaseName string = 'adventure'
param containerRegistryName string = ''
param containerAppsEnvName string = ''
param containerAppsAppName string = ''
param userAssignedIdentityName string = ''
param kvName string = ''

var abbrs = loadJsonContent('./abbreviations.json')

// tags that should be applied to all resources.
var tags = {
  // Tag all resources with the environment name.
  'azd-env-name': environmentName
}

// Generate a unique token to be used in naming resources.
// Remove linter suppression after using.
#disable-next-line no-unused-vars
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// Name of the service defined in azure.yaml
// A tag named azd-service-name with this value should be applied to the service host resource, such as:
//   Microsoft.Web/sites for appservice, function
// Example usage:
//   tags: union(tags, { 'azd-service-name': apiServiceName })
#disable-next-line no-unused-vars
var apiServiceName = 'python-api'

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : 'rg-${environmentName}'
  location: location
  tags: tags
}

// Security resources
module kv 'core/security/keyvault/keyvault.bicep' = {
  name: 'kv'
  scope: resourceGroup
  params: {
    name: !empty(kvName) ? kvName : '${abbrs.keyVault}-${resourceToken}'
    location: location
    tags: tags
    principalId: principalId
  }
}

module kvSecret 'core/security/keyvault/keyvault-secret.bicep' = {
  name: 'kvSecret'
  scope: resourceGroup
  params: {
    keyVaultName: kv.outputs.name
    name: 'cosmosconnectionstring'
    secretValue: cosmos.outputs.connectionString
  }
}


// Give the API access to KeyVault
module apiKeyVaultAccess 'core/security/keyvault/keyvault-access.bicep' = {
  name: 'api-keyvault-access'
  scope: resourceGroup
  params: {
    keyVaultName: kv.outputs.name
    principalId: identity.outputs.principalId
  }
}

// Give the User access to KeyVault
module userKeyVaultAccess 'core/security/keyvault/keyvault-access.bicep' = {
  name: 'user-keyvault-access'
  scope: resourceGroup
  params: {
    keyVaultName: kv.outputs.name
    principalId: principalId
  }
}

// Use assigned identity
module identity 'app/identity.bicep' = {
  name: 'identity'
  scope: resourceGroup
  params: {
    identityName: !empty(userAssignedIdentityName) ? userAssignedIdentityName : '${abbrs.userAssignedIdentity}-${resourceToken}'
    location: location
    tags: tags
  }
}

// The application database
module cosmos './app/db.bicep' = {
  name: 'cosmos'
  scope: resourceGroup
  params: {
    accountName: !empty(cosmosAccountName) ? cosmosAccountName : '${abbrs.cosmosDbAccount}${resourceToken}'
    databaseName: cosmosDatabaseName
    location: location
    tags: tags
  }
}

// Container registry
module registry 'app/registry.bicep' = {
  name: 'registry'
  scope: resourceGroup
  params: {
    registryName: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistry}${resourceToken}'
    location: location
    tags: tags
  }
}

// Web app
module web 'app/web.bicep' = {
  name: 'web'
  scope: resourceGroup
  params: {
    envName: !empty(containerAppsEnvName) ? containerAppsEnvName : '${abbrs.containerAppsEnv}-${resourceToken}'
    appName: !empty(containerAppsAppName) ? containerAppsAppName : '${abbrs.containerAppsApp}-${resourceToken}'
    databaseAccountEndpoint: cosmos.outputs.endpoint
    userAssignedManagedIdentity: {
      resourceId: identity.outputs.resourceId
      clientId: identity.outputs.clientId
    }
    location: location
    tags: tags
    serviceTag: 'web'
    keyVaultEndpoint: kv.outputs.endpoint
    cosmosconnectionstring: cosmos.outputs.connectionString
  }
}

// Add outputs from the deployment here, if needed.
//
// This allows the outputs to be referenced by other bicep deployments in the deployment pipeline,
// or by the local machine as a way to reference created resources in Azure for local development.
// Secrets should not be added here.
//
// Outputs are automatically saved in the local azd environment .env file.
// To see these outputs, run `azd env get-values`,  or `azd env get-values --output json` for json output.
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId


// Database outputs
output AZURE_COSMOS_ENDPOINT string = cosmos.outputs.endpoint

// Container outputs
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = registry.outputs.endpoint
output AZURE_CONTAINER_REGISTRY_NAME string = registry.outputs.name

// Application outputs
output AZURE_CONTAINER_APP_ENDPOINT string = web.outputs.endpoint
output AZURE_CONTAINER_ENVIRONMENT_NAME string = web.outputs.envName

// Identity outputs
output AZURE_USER_ASSIGNED_IDENTITY_NAME string = identity.outputs.name

// Security outputs
output KEYVAULT_ENDPOINT string = kv.outputs.endpoint
output COSMOS_CONNECTION_STRING string = cosmos.outputs.connectionString
