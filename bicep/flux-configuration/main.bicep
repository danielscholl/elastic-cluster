metadata name = 'Kubernetes Configuration Flux Configurations'
metadata description = 'This module deploys a Kubernetes Configuration Flux Configuration.'
metadata owner = 'Azure/module-maintainers'

@description('Required. The name of the Flux Configuration.')
param name string

@description('Optional. Enable/Disable usage telemetry for module.')
param enableTelemetry bool = true

@description('Required. The name of the AKS cluster that should be configured.')
param clusterName string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. The name of the storage account to be used.')
param storageAccountName string = ''

@description('Conditional. Parameters to reconcile to the GitRepository source kind type. Required if `sourceKind` is `Bucket`.')
param bucket object?

@description('Conditional. Parameters to reconcile to the AzureBlob source kind type. Required if `sourceKind` is `AzureBlob`.')
param azureBlob object?

@description('Optional. Key-value pairs of protected configuration settings for the configuration.')
@secure()
param configurationProtectedSettings object?

@description('Conditional. Parameters to reconcile to the GitRepository source kind type. Required if `sourceKind` is `GitRepository`.')
param gitRepository object?

@description('Required. Array of kustomizations used to reconcile the artifact pulled by the source type on the cluster.')
param kustomizations object

@description('Required. The namespace to which this configuration is installed to. Maximum of 253 lower case alphanumeric characters, hyphen and period only.')
param namespace string

@description('Date Stamp - Used for sentinel in configuration store.')
param dateStamp string = utcNow()

@allowed([
  'cluster'
  'namespace'
])
@description('Required. Scope at which the configuration will be installed.')
param scope string

@allowed([
  'Bucket'
  'GitRepository'
  'AzureBlob'
])
@description('Required. Source Kind to pull the configuration data from.')
param sourceKind string

@description('Optional. Whether this configuration should suspend its reconciliation of its kustomizations and sources.')
param suspend bool = false

#disable-next-line no-deployments-resources
resource avmTelemetry 'Microsoft.Resources/deployments@2024-03-01' = if (enableTelemetry) {
  name: '46d3xbcp.res.kubernetesconfiguration-fluxconfig.${replace('-..--..-', '.', '-')}.${substring(uniqueString(deployment().name, location), 0, 4)}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
      outputs: {
        telemetry: {
          type: 'String'
          value: 'For more information, see https://aka.ms/avm/TelemetryInfo'
        }
      }
    }
  }
}

resource managedCluster 'Microsoft.ContainerService/managedClusters@2022-07-01' existing = {
  name: clusterName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

var sasProperties = {
  signedServices: 'b'
  signedResourceTypes: 'sco'
  signedPermission: 'rl'
  signedProtocol: 'https'
  signedExpiry: dateTimeAdd(dateStamp, 'P1Y')
}
var sasToken = storageAccount.listAccountSas('2022-09-01', sasProperties).accountSasToken

resource fluxConfiguration 'Microsoft.KubernetesConfiguration/fluxConfigurations@2024-04-01-preview' = {
  name: name
  scope: managedCluster
  properties: {
    bucket: bucket
    azureBlob: storageAccountName != '' ? (azureBlob ?? {}) != {} ? union(azureBlob ?? {}, { sasToken: sasToken }) : {
      sasToken: sasToken
    } : azureBlob
    configurationProtectedSettings: configurationProtectedSettings
    gitRepository: gitRepository
    kustomizations: kustomizations
    namespace: namespace
    scope: scope
    sourceKind: sourceKind
    suspend: suspend
  }
}

@description('The name of the flux configuration.')
output name string = fluxConfiguration.name

@description('The resource ID of the flux configuration.')
output resourceId string = fluxConfiguration.id

@description('The name of the resource group the flux configuration was deployed into.')
output resourceGroupName string = resourceGroup().name
