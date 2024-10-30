param backupVaultName string
param snapshotResourceGroupId string
param clusterName string
param policyName string

resource backupVault 'Microsoft.DataProtection/backupVaults@2022-11-01-preview' existing = {
  name: backupVaultName
}

resource backupPolicy 'Microsoft.DataProtection/backupVaults/backupPolicies@2024-04-01' existing = {
  name: policyName
}

resource existingManagedCluster 'Microsoft.ContainerService/managedClusters@2024-04-02-preview' existing = {
  name: clusterName
}

resource backupInstanceKubernetes 'Microsoft.DataProtection/backupVaults/backupInstances@2024-04-01' = {
  name: '${guid(backupVaultName, clusterName, 'fullbackup')}-fullbackup'
  parent: backupVault // Parent is the Backup Vault
  properties: {
    friendlyName: 'AKS Backup Instance' 
    dataSourceInfo: {
      datasourceType: 'Microsoft.ContainerService/managedClusters' // Data source is a Kubernetes cluster
      objectType: 'Datasource' // Datasource object
      resourceID: existingManagedCluster.id
      resourceLocation: resourceGroup().location
      resourceName: existingManagedCluster.name
      resourceType: 'Microsoft.ContainerService/managedClusters'
      resourceUri: existingManagedCluster.id
    }
    dataSourceSetInfo: {
      datasourceType: 'Microsoft.ContainerService/managedClusters'
      objectType: 'DatasourceSet'
      resourceID: existingManagedCluster.id
      resourceLocation: resourceGroup().location
      resourceName: existingManagedCluster.name
      resourceType: 'Microsoft.ContainerService/managedClusters'
      resourceUri: existingManagedCluster.id
    }
    // A friendly name for the backup instance
    objectType: 'BackupInstance' // Object type of the instance
    policyInfo: {
      policyId: backupPolicy.id
      policyParameters: {
        backupDatasourceParametersList: [
          {
            objectType: 'KubernetesClusterBackupDatasourceParameters'
            includeClusterScopeResources: true
            includedNamespaces: [
              'cert-manager'
              'default'
              'elastic'
              'sample'
            ]
            excludedNamespaces: []
            includedResourceTypes: []
            excludedResourceTypes: []
            labelSelectors: []
            snapshotVolumes: true
          }
        ]
        dataStoreParametersList: [
          {
            dataStoreType: 'OperationalStore'
            objectType: 'AzureOperationalStoreParameters'
            resourceGroupId: snapshotResourceGroupId
          }
        ]
      }
    }
    validationType: 'ShallowValidation'
  }
}
