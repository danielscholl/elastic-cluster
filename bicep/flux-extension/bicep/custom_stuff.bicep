@description('The name of the Managed Cluster resource.')
param clusterName string


@description('The name of the storage account to be used.')
param storageAccountName string

@description('Optional. The managed identity definition for this resource.')
param managedIdentities managedIdentitiesType

var formattedUserAssignedIdentities = reduce(
  map((managedIdentities.?userAssignedResourcesIds ?? []), (id) => { '${id}': {} }),
  {},
  (cur, next) => union(cur, next)
) // Converts the flat array to an object like { '${id1}': {}, '${id2}': {} }

var identity = !empty(managedIdentities)
  ? {
      type: !empty(managedIdentities.?userAssignedResourcesIds ?? {}) ? 'UserAssigned' : null
      userAssignedIdentities: !empty(formattedUserAssignedIdentities) ? formattedUserAssignedIdentities : null
    }
  : null


resource managedCluster 'Microsoft.ContainerService/managedClusters@2024-04-02-preview' existing = {
  name: clusterName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

// Configure the AKS Backup Extension
/*
The extension object has an object called aksAssignedIdentity. This object has a property called principalId.
This is the principal ID of the managed identity that is assigned to the extension which would be used for a role assignment.
The object does not have a clientId property which is needed for flux to work against AzureBlob.

"aksAssignedIdentity": {
    "principalId": "00000000-0000-0000-0000-000000000000",
    "tenantId": null,
    "type": null
  },
*/
resource aksExtension 'Microsoft.KubernetesConfiguration/extensions@2023-05-01' existing = {
  name: 'flux'
  scope: managedCluster
}


// Role Assignment for Backup Extension to act as Storage Blob Data Contributor
resource roleBlobExtensionToStorageAccount 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, aksExtension.id, 'Storage Blob Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: aksExtension.properties.aksAssignedIdentity.principalId
  }
}

resource trustedRoleBinding 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'trustedRoleBindingWithClientId'
  location: resourceGroup().location
  kind: 'AzureCLI'

  identity: identity
  
  properties: {
    storageAccountSettings: {
      storageAccountKey: listKeys(storageAccount.id, '2023-01-01').keys[0].value
      storageAccountName: last(split(storageAccount.id, '/'))
    }
    azCliVersion: '2.63.0'

    timeout: 'PT30M'
    retentionInterval: 'PT1H'

    environmentVariables: [
      {
        name: 'rgName'
        value: resourceGroup().name
      }
      {
        name: 'clusterName'
        value: clusterName
      }
      {
        name: 'bindingName'
        value: 'backup-binding'
      }
    ]
    /*
    This script is responsible for creating the role binding for the extension to act as a backup operator.
    It also retrieves the client ID of the managed identity which is needed for flux to work against AzureBlob.
    */
    scriptContent: '''
      az login --identity
      existingBinding=$(az aks trustedaccess rolebinding list --resource-group $rgName --cluster-name $clusterName --query "[?name=='$bindingName']" -o tsv)
      if [ -z "$existingBinding" ]; then
        az aks trustedaccess rolebinding create --resource-group $rgName --cluster-name $clusterName --name $bindingName --source-resource-id $vaultId --roles Microsoft.DataProtection/backupVaults/backup-operator
      else
        echo "Role binding $bindingName already exists."
      fi
    '''
  }
}



resource getClientId 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'getClientId'
  location: resourceGroup().location
  kind: 'AzureCLI'

  identity: identity
  
  properties: {
    storageAccountSettings: {
      storageAccountKey: listKeys(storageAccount.id, '2023-01-01').keys[0].value
      storageAccountName: last(split(storageAccount.id, '/'))
    }
    azCliVersion: '2.63.0'

    timeout: 'PT30M'
    retentionInterval: 'PT1H'

    environmentVariables: [
      {
        name: 'rgName'
        value: managedCluster.properties.nodeResourceGroup
      }
      {
        name: 'clusterName'
        value: clusterName
      }
      {
        name: 'principalId'
        value: aksExtension.properties.aksAssignedIdentity.principalId
      }
    ]
    /*
    This script is responsible for creating the role binding for the extension to act as a backup operator.
    It also retrieves the client ID of the managed identity which is needed for flux to work against AzureBlob.
    */
    scriptContent: '''
      az login --identity

      echo "Listing all identities"
      az identity list -o table

      echo "Looking up identities in ResourceGroup $rgName"
      az identity list --resource-group $rgName -o table

      echo "Looking up client ID for $principalId in ResourceGroup $rgName"
      // clientId=$(az identity list --resource-group $rgName --query "[?principalId=='$principalId'] | [0].clientId" -otsv)
      clientId=9d36b86c-ccf3-45df-b1ac-523db2c45dd1
      
      echo "Found ClientId: $clientId"
      echo "{\"clientId\":\"$clientId\"}" > $AZ_SCRIPTS_OUTPUT_PATH
    '''
  }
}



// @description('The output of the deployment script.')
// output outputs object = getClientId.properties.?outputs ?? {}

output clientId string = getClientId.properties.outputs.clientId
output managedIdentityId string = aksExtension.properties.aksAssignedIdentity.principalId


type managedIdentitiesType = {
  @description('Optional. The resource ID(s) to assign to the resource.')
  userAssignedResourcesIds: string[]
}?
