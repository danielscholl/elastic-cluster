@description('The name of the storage account to be used.')
param storageAccountName string

@description('The principal id to assign the role.')
param principalId string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}


// Role Assignment for Backup Vault as Storage Blob Data Reader
resource roleReaderVaultToStorageBlobDataReader 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storageAccount.name, storageAccount.id, 'Storage Blob Data Reader')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1') // Storage Blob Data Reader role definition ID
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

