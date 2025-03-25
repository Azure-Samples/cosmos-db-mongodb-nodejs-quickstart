using './main.bicep'

param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'development')
param location = readEnvironmentVariable('AZURE_LOCATION', 'westus')
param azureDeploymentPrincipalId = readEnvironmentVariable('AZURE_PRINCIPAL_ID', '')
param deploymentType = readEnvironmentVariable('MONGODB_DEPLOYMENT_TYPE', 'request-unit')
