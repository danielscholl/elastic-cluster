@description('Optional. DNS Zone Resource ID.')
param dnsZoneResourceId string = ''

@description('The principal id to assign the role.')
param principalId string

resource dnsRole 'Microsoft.Authorization/roleDefinitions@2024-01-01' =  {
  name: 'DNS Zone Contributor'
  properties: {
    roleName: 'DNS Zone Contributor'
  }
}
