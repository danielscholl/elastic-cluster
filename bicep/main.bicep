targetScope = 'resourceGroup'
metadata name = 'Managed Kubernetes.'
metadata description = 'This deploys a managed Kubernetes cluster.'


@description('Specify the Azure region to place the application definition.')
param location string = resourceGroup().location

@description('Location of the Software Source Code.')
param softwareSource string = 'https://github.com/danielscholl/elastic-cluster'

@description('Enable Software from Azure Blob Storage (Requires Storage Account Key Access).')
param enableBlobSoftware bool = false

@description('Enable Backup to Backup Vaults (Requires Storage Account Key Access).')
param enableAKSBackup bool = false

@description('The size of the VM to use for the cluster.')
@allowed([
  'Standard_D4lds_v5'
  'Standard_D4s_v3'
  'Standard_DS3_v2'
])
param vmSize string = 'Standard_D4s_v3'

@allowed([
  '8.15.3'
  '8.14.3'
  '7.17.24'
  '7.17.22'
  '7.16.3'
])
@description('Elastic Version')
param elasticVersion string = '8.15.3'

@description('Number of Instances')
param instances int = 1

@description('Optional. DNS Zone Resource ID.')
param dnsZoneResourceId string = ''

@description('Date Stamp - Used for sentinel in configuration store.')
param dateStamp string = utcNow()


@description('Internal Configuration Object')
var configuration = {
  name: 'main'
  displayName: 'Main Resources'
  logs: {
    sku: 'PerGB2018'
    retention: 30
  }
  vault: {
    sku: 'standard'
  }
  appconfig: {
    sku: 'Standard'
  }
  storage: {
    sku: 'Standard_LRS'
    tier: 'Hot'
  }
  registry: {
    sku: 'Standard'
  }
  cluster: {
    sku: 'Base'  // or 'Automatic'
    tier: 'Standard'
    vmSize: vmSize
  }
  features: {
    enableStampElastic: true
    enablePrivateSoftware: enableBlobSoftware
    enableMesh: false
    enablePaasPool: false
    enableStampTest: false
    enableBackup: enableAKSBackup
  }
}

@description('Unique ID for the resource group')
var rg_unique_id = '${replace(configuration.name, '-', '')}${uniqueString(resourceGroup().id, configuration.name)}'


/////////////////////////////////////////////////////////////////////
//  Identity Resources                                             //
/////////////////////////////////////////////////////////////////////
module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: '${configuration.name}-user-managed-identity'
  params: {
    // Required parameters
    name: rg_unique_id
    location: location
    // Assign Tags
    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }
  }
}


/////////////////////////////////////////////////////////////////////
//  Monitoring Resources                                           //
/////////////////////////////////////////////////////////////////////
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.7.0' = {
  name: '${configuration.name}-log-analytics'
  params: {
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id
    location: location
    // Assign Tags
    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }

    skuName: configuration.logs.sku
  }
}


/////////////////////////////////////////////////////////////////////
//  Cluster Resources                                              //
/////////////////////////////////////////////////////////////////////
// AVM doesn't support things like AKS Automatic SKU, so we used a fork of the module.
module managedCluster './managed-cluster/main.bicep' = {
  name: '${configuration.name}-cluster'
  params: {
    // Required parameters
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id
    location: location

    // Assign Tags
    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }

    skuTier: configuration.cluster.tier
    skuName: configuration.cluster.sku

    diagnosticSettings: [
      {
        name: 'customSetting'
        logCategoriesAndGroups: [
          {
            category: 'kube-apiserver'
          }
          {
            category: 'kube-controller-manager'
          }
          {
            category: 'kube-scheduler'
          }
          {
            category: 'cluster-autoscaler'
          }
        ]
        metricCategories: [
          {
            category: 'AllMetrics'
          }
        ]
        workspaceResourceId: logAnalytics.outputs.resourceId
      }
    ]

    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Azure Kubernetes Service RBAC Cluster Admin'
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
      // Role Assignment required for the trusted role binding deployment script to execute.
      {
        roleDefinitionIdOrName: 'Kubernetes Agentless Operator'
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
    ]

    aksServicePrincipalProfile: {
      clientId: 'msi'
    }
    managedIdentities: {
      systemAssigned: false  
      userAssignedResourcesIds: [
        identity.outputs.resourceId
      ]
    }

    // Network Settings
    networkPlugin: 'azure'
    networkPluginMode: 'overlay'
    networkDataplane: 'cilium'
    publicNetworkAccess: 'Enabled'
    outboundType: 'managedNATGateway'
    enablePrivateCluster: false
    dnsZoneResourceId: !empty(dnsZoneResourceId) ? dnsZoneResourceId : null

    // Access Settings
    disableLocalAccounts: true
    enableRBAC: true
    aadProfileManaged: true
    nodeResourceGroupLockDown: true

    // Observability Settings
    enableAzureDefender: true
    enableContainerInsights: true
    monitoringWorkspaceId: logAnalytics.outputs.resourceId
    enableAzureMonitorProfileMetrics: true
    costAnalysisEnabled: true

    // Ingress Settings
    webApplicationRoutingEnabled: !configuration.features.enableMesh
    istioServiceMeshEnabled: configuration.features.enableMesh
    istioIngressGatewayEnabled: configuration.features.enableMesh
    istioIngressGatewayType: configuration.features.enableMesh ? 'External' : null

    // Plugin Software
    enableStorageProfileDiskCSIDriver: true
    enableStorageProfileFileCSIDriver: true
    enableStorageProfileSnapshotController: true
    enableStorageProfileBlobCSIDriver: true    
    enableKeyvaultSecretsProvider: true
    enableSecretRotation: true
    enableImageCleaner: true
    imageCleanerIntervalHours: 168
    enableOidcIssuerProfile: true
    enableWorkloadIdentity: true
    azurePolicyEnabled: true
    omsAgentEnabled: true
    
    // Auto-Scaling
    vpaAddon: true
    kedaAddon: true
    enableNodeAutoProvisioning: true
    
    maintenanceConfiguration: {
      maintenanceWindow: {
        schedule: {
          daily: null
          weekly: {
            intervalWeeks: 1
            dayOfWeek: 'Sunday'
          }
          absoluteMonthly: null
          relativeMonthly: null
        }
        durationHours: 4
        utcOffset: '+00:00'
        startDate: '2024-10-01'
        startTime: '00:00'
      }
    }

    primaryAgentPoolProfile: [
      {
        name: 'systempool'
        mode: 'System'
        vmSize: configuration.cluster.vmSize
        count: 1
        securityProfile: {
          sshAccess: 'Disabled'
        }
        osType: 'Linux'
        osSKU: 'AzureLinux'
      }
    ]

    // Additional Agent Pool Configurations
    agentPools: concat([
      // Default User Pool has no taints or labels
      {
        name: 'defaultpool'
        mode: 'User'
        vmSize: configuration.cluster.vmSize
        count: 1
        securityProfile: {
          sshAccess: 'Disabled'
        }
        osType: 'Linux'
        osSKU: 'AzureLinux'
      }
    ], configuration.features.enablePaasPool ? [
      {
        name: 'paaspool'
        mode: 'User'
        vmSize: configuration.cluster.vmSize
        count: 1
        securityProfile: {
          sshAccess: 'Disabled'
        }
        osType: 'Linux'
        osSKU: 'AzureLinux'
        nodeTaints: ['app=cluster-paas:NoSchedule']
        nodeLabels: {
          app: 'cluster-paas'
        }
      }
    ] : [])
  }
}

// Policy Assignments custom module to apply the policies to the cluster.
module policy './aks_policy.bicep' = {
  name: '${configuration.name}-policy-assignment'
  params: {
    clusterName: managedCluster.outputs.name
  }
  dependsOn: [
    managedCluster
  ]
}

// AKS Extensions custom module to apply the app config provider extension to the cluster.
module appConfigExtension './aks_appconfig_extension.bicep' = {
  name: '${configuration.name}-appconfig-extension'
  params: {
    clusterName: managedCluster.outputs.name
  }
  dependsOn: [
    managedCluster
  ]
}

// Custom module to retrieve the NAT Public IP after the cluster is created.
module natClusterIP './nat_public_ip.bicep' = {
  name: '${configuration.name}-nat-public-ip'
  params: {
    publicIpResourceId: managedCluster.outputs.outboundIpResourceId
  }
}

//  Federated Credentials
@description('Federated Identities for Namespaces')
var federatedIdentityCredentials = [
  {
    name: 'federated-ns_default'
    subject: 'system:serviceaccount:default:workload-identity-sa'
  }
  {
    name: 'federated-ns_elastic'
    subject: 'system:serviceaccount:elastic:workload-identity-sa'
  }
  {
    name: 'federated-ns_flux-system'
    subject: 'system:serviceaccount:flux-system:source-controller'
  }
]

// Custom module to create federated credentials for the namespaces.
@batchSize(1)
module federatedCredentials './federated_identity.bicep' = [for (cred, index) in federatedIdentityCredentials: {
  name: '${configuration.name}-${cred.name}'
  params: {
    name: cred.name
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: managedCluster.outputs.oidcIssuerUrl
    userAssignedIdentityName: identity.outputs.name
    subject: cred.subject
  }
  dependsOn: [
    managedCluster
  ]
}]


/////////////////////////////////////////////////////////////////////
//  Image Resources                                             //
/////////////////////////////////////////////////////////////////////
module registry 'br/public:avm/res/container-registry/registry:0.5.1' = {
  name: '${configuration.name}-registry'
  params: {
    // Required parameters
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id  
    location: location
    acrSku: configuration.registry.sku

    // Assign Tags
    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }

    diagnosticSettings: [
      {
        workspaceResourceId: logAnalytics.outputs.resourceId
      }
    ]

    roleAssignments: [
      {
        roleDefinitionIdOrName: 'AcrPull'
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName: 'AcrPull'
        principalId: managedCluster.outputs.kubeletIdentityObjectId
        principalType: 'ServicePrincipal'
      }
    ]

    // Non-required parameters
    acrAdminUserEnabled: false
    azureADAuthenticationAsArmPolicyStatus: 'disabled'
  }
  
}


/////////////////////////////////////////////////////////////////////
//  Configuration Resources                                        //
/////////////////////////////////////////////////////////////////////
@description('App Configuration Values')
var configmapServices = [
  {
    name: 'sentinel'
    value: dateStamp
    label: 'common'
  }
  {
    name: 'tenant_id'
    value: subscription().tenantId
    contentType: 'text/plain'
    label: 'system-values'
  }
  {
    name: 'azure_msi_client_id'
    value: identity.outputs.clientId
    contentType: 'text/plain'
    label: 'system-values'
  }
  {
    name: 'keyvault_uri'
    value: keyvault.outputs.uri
    contentType: 'text/plain'
    label: 'system-values'
  }
  {
    name: 'instances'
    value: string(instances)
    contentType: 'application/json'
    label: 'elastic-values'
  }
  {
    name: 'version'
    value: string(elasticVersion)
    contentType: 'text/plain'
    label: 'elastic-values'
  }
  {
    name: 'storageSize'
    value: '30Gi'
    contentType: 'text/plain'
    label: 'elastic-values'
  }
  {
    name: 'storageClass'
    value: 'managed-premium'
    contentType: 'text/plain'
    label: 'elastic-values'
  }
]

// AVM doesn't have a nice way to create the values in the store, so we forked the module.
module configurationStore './app-configuration/main.bicep' = {
  name: '${configuration.name}-appconfig'
  params: {
    // Required parameters
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id    
    location: location
    sku: configuration.appconfig.sku

    // Assign Tags
    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }

    diagnosticSettings: [
      {
        workspaceResourceId: logAnalytics.outputs.resourceId
      }
    ]

    roleAssignments: [
      {
        roleDefinitionIdOrName: 'App Configuration Data Reader'
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
    ]

    enablePurgeProtection: false
    disableLocalAuth: true

    // Add Configuration
    keyValues: concat(union(configmapServices, []))
  }
  dependsOn: [
    managedCluster
  ]
}


// Static secrets
var staticSecrets = [
  {
    secretName: 'tenant-id'
    secretValue: subscription().tenantId
  }
  {
    secretName: 'subscription-id'
    secretValue: subscription().subscriptionId
  }
]

var baseElasticKey = '${uniqueString(resourceGroup().id, location)}${uniqueString(subscription().id, deployment().name)}'

// Elastic secrets, flattened to individual objects
var elasticSecrets = [for i in range(0, instances): [
  {
    secretName: 'elastic-username-${i}'
    secretValue: 'elastic-user'
  }
  {
    secretName: 'elastic-password-${i}'
    secretValue: substring(uniqueString(resourceGroup().id, location, 'saltpass${i}'), 0, 13)
  }
  {
    secretName: 'elastic-key-${i}'
    secretValue: substring('${baseElasticKey}${baseElasticKey}${baseElasticKey}', 0, 32)
  }
]]

// Use array concatenation to join the static and elastic secrets
var vaultSecrets = union(staticSecrets, flatten(elasticSecrets))


module keyvault 'br/public:avm/res/key-vault/vault:0.9.0' = {
  name: '${configuration.name}-keyvault'
  params: {
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id
    location: location
    sku: configuration.vault.sku
    
    // Assign Tags
    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }

    diagnosticSettings: [
      {
        workspaceResourceId: logAnalytics.outputs.resourceId
      }
    ]

    enablePurgeProtection: false
    
    // Configure RBAC
    enableRbacAuthorization: true
    roleAssignments: [{
      roleDefinitionIdOrName: 'Key Vault Secrets User'
      principalId: identity.outputs.principalId
      principalType: 'ServicePrincipal'
    }]

    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [
        {
          value: natClusterIP.outputs.ipAddress
        }
      ]
    }

    // Configure Secrets
    secrets: [
      for secret in vaultSecrets: {
        name: secret.secretName
        value: secret.secretValue
      }
    ]
  }
  dependsOn: [
    managedCluster
    natClusterIP
  ]
}


/////////////////////////////////////////////////////////////////////
//  Observability Resources                                        //
/////////////////////////////////////////////////////////////////////
module prometheus 'aks_prometheus.bicep' = {
  name: '${configuration.name}-managed-prometheus'
  params: {
    // Basic Details
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id
    location: location

    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }

    publicNetworkAccess: 'Enabled'    
    clusterName: managedCluster.outputs.name
    actionGroupId: ''
  }
  dependsOn: [
    managedCluster
  ]
}

module grafana 'aks_grafana.bicep' = {
  name: '${configuration.name}-managed-grafana'

  params: {
    // Basic Details
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id
    location: location
    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }

    skuName: 'Standard'
    apiKey: 'Enabled'
    autoGeneratedDomainNameLabelScope: 'TenantReuse'
    deterministicOutboundIP: 'Disabled'
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
    prometheusName: prometheus.outputs.name
  }
  dependsOn: [
    prometheus
  ]
}



/////////////////////////////////////////////////////////////////////
//  Backup Resources                                               //
/////////////////////////////////////////////////////////////////////
module storageAccount 'br/public:avm/res/storage/storage-account:0.9.1' = {
  name: '${configuration.name}-storage'
  params: {
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id
    location: location
    skuName: configuration.storage.sku
    accessTier: configuration.storage.tier
    // Assign Tags
    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }

    diagnosticSettings: [
      {
        workspaceResourceId: logAnalytics.outputs.resourceId
      }
    ]

    roleAssignments: [
      // This role is used for the gitops upload to talk to the storage account.
      {
        roleDefinitionIdOrName: 'Storage Blob Data Owner'
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
      // This role is used for backup to talk to the storage account.
      {
        roleDefinitionIdOrName: 'Contributor'
        principalId: managedCluster.outputs.kubeletIdentityObjectId
        principalType: 'ServicePrincipal'
      }
    ]

    allowBlobPublicAccess: false
    allowSharedKeyAccess: configuration.features.enablePrivateSoftware
    publicNetworkAccess: 'Enabled'

    networkAcls: {
      defaultAction: 'Allow'
    }

    managedIdentities: {
      userAssignedResourceIds: [
        identity.outputs.resourceId
      ]
    }

    blobServices: {
      containers: [
        {
          name: 'gitops'
        }
        {
          name: 'backup'
        }
      ]
    }
  }
}

module backupVault 'br/public:avm/res/data-protection/backup-vault:0.7.0' = if (configuration.features.enableBackup) {
  name: '${configuration.name}-backup'
  params: {
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id
    location: location
    // Assign Tags
    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }

    managedIdentities: {
      systemAssigned: true
    }

    roleAssignments: [
      // Role Assignment requiredfor the trusted role binding deployment script to execute.
      {
        roleDefinitionIdOrName: 'Backup Reader'
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
    ]

    securitySettings: {
      softDeleteSettings: {
        state: 'Off'
        retentionDurationInDays: 14
      }
    }

    backupPolicies: [
      {
        name: 'Manual'
        properties: {
          datasourceTypes: [
            'Microsoft.ContainerService/managedClusters'
          ]
          objectType: 'BackupPolicy'
          policyRules: [
            {
              lifecycles: [
                {
                  deleteAfter: {
                    duration: 'P7D'
                    objectType: 'AbsoluteDeleteOption'
                  }
                  targetDataStoreCopySettings: []
                  sourceDataStore: {
                    dataStoreType: 'OperationalStore'
                    objectType: 'DataStoreInfoBase'
                  }
                }
              ]
              isDefault: true
              name: 'Default'
              objectType: 'AzureRetentionRule'
            }
            {
              backupParameters: {
                backupType: 'Incremental'
                objectType: 'AzureBackupParams'
              }
              trigger: {
                schedule: {
                  repeatingTimeIntervals: [
                    'R/2024-10-22T18:08:05+00:00/PT4H'
                  ]
                  timeZone: 'Coordinated Universal Time'
                }
                taggingCriteria: [
                  {
                    tagInfo: {
                      tagName: 'Default'
                      id: 'Default_'
                    }
                    taggingPriority: 99
                    isDefault: true
                  }
                ]
                objectType: 'ScheduleBasedTriggerContext'
              }
              dataStore: {
                dataStoreType: 'OperationalStore'
                objectType: 'DataStoreInfoBase'
              }
              name: 'BackupHourly'
              objectType: 'AzureBackupRule'
            }
          ]
        }
      }
    ]
  }
}

// Custom module to create the backup extension on the cluster and assign the proper roles.
module backupExtension './aks_backup_extension.bicep' = if (configuration.features.enableBackup) {
  name: '${configuration.name}-backup-extension'
  params: {
    clusterName: managedCluster.outputs.name
    storageAccountName: storageAccount.outputs.name
    backupVaultName: configuration.features.enableBackup ? backupVault.outputs.name : ''
  }
}

// Had to use a deployment script to create the trusted role binding as this is only a cli command.
module trustedRoleBinding 'br/public:avm/res/resources/deployment-script:0.4.0' = if (configuration.features.enableBackup) {
  name: '${configuration.name}-script-trustedRoleBinding'
  
  params: {
    kind: 'AzureCLI'
    name: 'aksTrustedRoleBindingScript'
    azCliVersion: '2.63.0'
    location: location
    managedIdentities: {
      userAssignedResourcesIds: [
        identity.outputs.resourceId
      ]
    }

    environmentVariables: [
      {
        name: 'rgName'
        value: resourceGroup().name
      }
      {
        name: 'vaultId'
        value: configuration.features.enableBackup ? backupVault.outputs.resourceId : ''
      }
      {
        name: 'clusterName'
        value: managedCluster.outputs.name
      }
      {
        name: 'bindingName'
        value: 'backup-binding'
      }
    ]
    
    timeout: 'PT30M'
    retentionInterval: 'PT1H'

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

/////////////////////////////////////////////////////////////////////
//  Software Resources                                               //
/////////////////////////////////////////////////////////////////////
// Custom deployment script module to upload the gitops software configuration to the storage account.
module gitOpsUpload './software-upload/main.bicep' = {
  name: '${configuration.name}-storage-software-upload'
  params: {
    storageAccountName: storageAccount.outputs.name
    location: location
    useExistingManagedIdentity: true
    managedIdentityName: identity.outputs.name
    existingManagedIdentitySubId: subscription().subscriptionId
    existingManagedIdentityResourceGroupName:resourceGroup().name
    softwareSource: softwareSource
  }
  dependsOn: [
    storageAccount
    identity
  ]
}

// AVM doesn't support output of the principalId from the extension module so we have to use a deployment script to get it.
module fluxExtension './flux-extension/main.bicep' = {
  name: '${configuration.name}-flux-extension'
  params: {
    clusterName: managedCluster.outputs.name
    location: location
    extensionType: 'microsoft.flux'
    name: 'flux'    
    releaseNamespace: 'flux-system'
    releaseTrain: 'Stable'

    configurationSettings: {
      'multiTenancy.enforce': 'false'
      'helm-controller.enabled': 'true'
      'source-controller.enabled': 'true'
      'kustomize-controller.enabled': 'true'
      'notification-controller.enabled': 'true'
      'image-automation-controller.enabled': 'false'
      'image-reflector-controller.enabled': 'false'
    }
  }
}

// This is a custom module to get the clientId of the extension identity.
module extensionClientId 'br/public:avm/res/resources/deployment-script:0.4.0' = if (configuration.features.enablePrivateSoftware) {
  name: '${configuration.name}-script-clientId'
  
  params: {
    kind: 'AzureCLI'
    name: 'aksExtensionClientId'
    azCliVersion: '2.63.0'
    location: location
    managedIdentities: {
      userAssignedResourcesIds: [
        identity.outputs.resourceId
      ]
    }

    environmentVariables: [
      {
        name: 'rgName'
        value: '${resourceGroup().name}_aks_${managedCluster.outputs.name}_nodes'
      }
      {
        name: 'principalId'
        value: fluxExtension.outputs.principalId
      }
    ]
    
    timeout: 'PT30M'
    retentionInterval: 'PT1H'

    scriptContent: '''
      az login --identity

      echo "Looking up client ID for $principalId in ResourceGroup $rgName"
      clientId=$(az identity list --resource-group $rgName --query "[?principalId=='$principalId'] | [0].clientId" -otsv)
      
      echo "Found ClientId: $clientId"
      echo "{\"clientId\":\"$clientId\"}" | jq -c '.' > $AZ_SCRIPTS_OUTPUT_PATH
    '''
  }
  dependsOn: [
    fluxExtension
  ]
}

// This is a custom module to create the role assignment for the extension identity to the storage account blob.
module fluxExtensionRole './aks_flux_extension_role.bicep' = if (configuration.features.enablePrivateSoftware) {
  name: '${configuration.name}-flux-extension-role'
  params: {
    storageAccountName: storageAccount.outputs.name
    principalId: fluxExtension.outputs.principalId
  }
  dependsOn: [
    storageAccount
    extensionClientId
  ]
}

// AVM doesn't support azure blob as a gitops source yet we used a fork of the module to support it.
module fluxConfiguration './flux-configuration/main.bicep' = {
  name: '${configuration.name}-flux-configuration'
  params: {
    name: 'flux-system'
    clusterName: managedCluster.outputs.name
    location: location

    namespace: 'flux-system'
    scope: 'cluster'
    suspend: false
    sourceKind: configuration.features.enablePrivateSoftware ? 'AzureBlob' : 'GitRepository'
    
    gitRepository: !configuration.features.enablePrivateSoftware ? {
      repositoryRef: {
        branch: 'main'
      }
      sshKnownHosts: ''
      syncIntervalInSeconds: 60
      timeoutInSeconds: 300
      url: softwareSource
    } : null
    
    azureBlob: configuration.features.enablePrivateSoftware ? {
      containerName: 'gitops'
      url: storageAccount.outputs.primaryBlobEndpoint
      managedIdentity: {
        clientId: extensionClientId.outputs.outputs.clientId
      }
    } : null

    kustomizations: {
      global: {
        path: './software/stamp-global'
        dependsOn: []
        syncIntervalInSeconds: 300
        timeoutInSeconds: 300
        retryIntervalInSeconds: 300
        validation: 'none'
        prune: true
      }
      ...(configuration.features.enableStampTest ? {
        test: {
          path: './software/stamp-test'
          dependsOn: ['global']
          syncIntervalInSeconds: 300
          timeoutInSeconds: 300
          retryIntervalInSeconds: 300
          validation: 'none'
          prune: true
        }
      } : {})
      ...(configuration.features.enableStampElastic ? {
        elastic: {
          path: './software/stamp-elastic'
          dependsOn: ['global']
          syncIntervalInSeconds: 300
          timeoutInSeconds: 300
          retryIntervalInSeconds: 300
          validation: 'none'
          prune: true
        }
      } : {})
    }
  }
  dependsOn: configuration.features.enablePrivateSoftware ? [
    fluxExtension
    fluxExtensionRole
  ] :[
    fluxExtension
  ]
}


// Apply network ACL to the storage account  (Backup UI checks think we don't have access to the storage account)
module storageAcl './storage_acl.bicep' = if (!configuration.features.enableBackup && !configuration.features.enablePrivateSoftware) {
  name: '${configuration.name}-storage-acl'
  params: {
    storageName: storageAccount.outputs.name
    location: location
    skuName: configuration.storage.sku
    natClusterIP: natClusterIP.outputs.ipAddress
  }
  dependsOn: [
    gitOpsUpload
  ]
}

//--------------Config Map---------------
// SecretProviderClass --> tenantId, clientId, keyvaultName
// ServiceAccount --> tenantId, clientId
// AzureAppConfigurationProvider --> tenantId, clientId, configEndpoint, keyvaultUri, keyvaultName
@description('Default Config Map to get things needed for secrets and configmaps')
var configMaps = {
  appConfigTemplate: '''
values.yaml: |
  serviceAccount:
    create: false
    name: "workload-identity-sa"
  azure:
    tenantId: {0}
    clientId: {1}
    configEndpoint: {2}
    keyvaultUri: {3}
    keyvaultName: {4}
  iterateCount: {5}
  '''
}

// Custom module to create the initial config map for the App Configuration Provider
module appConfigMap './aks-config-map/main.bicep' = {
  name: '${configuration.name}-configmap'
  params: {
    aksName: managedCluster.outputs.name
    location: location
    name: 'system-values'
    namespace: 'default'
    
    // Order of items matters here.
    fileData: [
      format(configMaps.appConfigTemplate, 
             subscription().tenantId, 
             identity.outputs.clientId,
             configurationStore.outputs.endpoint,
             keyvault.outputs.uri,
             keyvault.outputs.name,
             instances)
    ]

    newOrExistingManagedIdentity: 'existing'
    managedIdentityName: identity.outputs.name
    existingManagedIdentitySubId: subscription().subscriptionId
    existingManagedIdentityResourceGroupName:resourceGroup().name
  }
  dependsOn: [
    managedCluster
    fluxConfiguration
    appConfigExtension
  ]
}
