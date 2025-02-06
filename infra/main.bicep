targetScope = 'resourceGroup'

@minLength(1)
@maxLength(64)
@description('Name to prefix all resources')
param name string = 'langfuse-test'

param keyVaultName string = '' // Set in main.parameters.json
param postgresServerName string = '' // Set in main.parameters.json
param logAnalyticsWorkspaceName string = '' // Set in main.parameters.json
param containerAppEnvName string = '' // Set in main.parameters.json
param containerAppName string = '' // Set in main.parameters.json
param databaseName string = 'langfuse' // Set in main.parameters.json

@minLength(1)
@description('Primary location for all resources')
param location string = 'eastus'

@secure()
param databasePassword string

@secure()
param nextAuthSecret string

@description('Id of the user or app to assign application roles')
param principalId string = ''

@secure()
param salt string

param useAuthentication bool = false
param authClientId string = ''
@secure()
param authClientSecret string = ''
param authTenantId string = ''

var databaseAdmin = 'dbadmin'
var resourceToken = toLower(uniqueString(subscription().id, name, location))

var tags = { 'azd-env-name': name }
var prefix = '${name}-${resourceToken}'


// Store secrets in a keyvault
module keyVault './core/security/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${replace(take(prefix, 17), '-', '')}-vault'
    location: location
    tags: tags
  }
}

// Give the principal access to KeyVault (currently user deploying the resources)
module principalKeyVaultAccess './core/security/keyvault-access.bicep' = {
  name: 'keyvault-access-${principalId}'
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: principalId
  }
}

module postgresServer 'core/database/flexibleserver.bicep' = {
  name: 'postgresql'
  params: {
    name: !empty(postgresServerName) ? postgresServerName : '${prefix}-postgresql'
    location: location
    tags: tags
    sku: {
      name: 'Standard_B1ms'
      tier: 'Burstable'
    }
    storage: {
      storageSizeGB: 32
    }
    version: '16'
    administratorLogin: databaseAdmin
    administratorLoginPassword: databasePassword
    databaseNames: [ databaseName ]
    allowAzureIPsFirewall: false
  }
}

module logAnalyticsWorkspace 'core/monitor/loganalytics.bicep' = {
  name: 'loganalytics'
  params: {
    name: !empty(logAnalyticsWorkspaceName) ? logAnalyticsWorkspaceName : '${prefix}-loganalytics'
    location: location
    tags: tags
  }
}

module containerAppEnv 'core/host/container-app-env.bicep' = {
  name: 'container-env'
  params: {
    name: !empty(containerAppEnvName) ? containerAppEnvName : '${prefix}-app'
    location: location
    tags: tags
    logAnalyticsWorkspaceName: logAnalyticsWorkspace.outputs.name
  }
}

module containerApp 'core/host/container-app.bicep' = {
  name: 'container'
  params: {
    name: !empty(containerAppName) ? containerAppName : '${prefix}-app'
    location: location
    tags: tags
    containerEnvId: containerAppEnv.outputs.id
    imageName: 'ghcr.io/langfuse/langfuse:2'
    targetPort: 3000
    env: [
      {
        name: 'DATABASE_HOST'
        value: postgresServer.outputs.fqdn
      }
      {
        name: 'DATABASE_NAME'
        value: databaseName
      }
      {
        name: 'DATABASE_USERNAME'
        value: databaseAdmin
      }
      {
        name: 'DATABASE_PASSWORD'
        secretRef: 'databasepassword'
      }
      {
        name: 'NEXTAUTH_URL'
        value: 'https://${containerAppName}.${containerAppEnv.outputs.defaultDomain}'
      }
      {
        name: 'NEXTAUTH_SECRET'
        secretRef: 'nextauthsecret'
      }
      {
        name: 'SALT'
        secretRef: 'salt'
      }
      {
        name: 'AUTH_AZURE_AD_CLIENT_ID'
        value: authClientId
      }
      {
        name: 'AUTH_AZURE_AD_CLIENT_SECRET'
        secretRef: 'authclientsecret'
      }
      {
        name: 'AUTH_AZURE_AD_TENANT_ID'
        value: authTenantId
      }
      {
        name: 'AUTH_DISABLE_USERNAME_PASSWORD'
        value: useAuthentication ? 'true' : 'false'
      }
    ]
    secrets: {
      databasepassword: databasePassword
      nextauthsecret: nextAuthSecret
      salt: salt
      authclientsecret: useAuthentication ? authClientSecret : 'unset'
    }
  }
}

var secrets = [
  {
    name: 'DATABASEPASSWORD'
    value: databasePassword
  }
  {
    name: 'NEXTAUTHSECRET'
    value: nextAuthSecret
  }
  {
    name: 'SALT'
    value: salt
  }
]

module keyVaultSecrets './core/security/keyvault-secret.bicep' = [for secret in secrets: {
  name: 'keyvault-secret-${secret.name}'
  params: {
    keyVaultName: keyVault.outputs.name
    name: secret.name
    secretValue: secret.value
  }
}]

output SERVICE_APP_URI string = containerApp.outputs.uri
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
