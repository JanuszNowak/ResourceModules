targetScope = 'managementGroup'

@description('Required. The group ID of the Management group.')
param name string

@description('Optional. The friendly name of the management group. If no value is passed then this field will be set to the group ID.')
param displayName string = ''

@description('Optional. The management group parent ID. Defaults to current scope.')
param parentId string = ''

@description('Optional. Array of role assignment objects to define RBAC on this resource.')
param roleAssignments array = []

@sys.description('Optional. Location deployment metadata.')
param location string = deployment().location

@description('Optional. Enable telemetry via the Customer Usage Attribution ID (GUID).')
param enableDefaultTelemetry bool = true

resource defaultTelemetry 'Microsoft.Resources/deployments@2021-04-01' = if (enableDefaultTelemetry) {
  name: 'pid-47ed15a6-730a-4827-bcb4-0fd963ffbd82-${uniqueString(deployment().name, location)}'
  location: location
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
    }
  }
}

resource managementGroup 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: name
  scope: tenant()
  properties: {
    displayName: displayName
    details: !empty(parentId) ? {
      parent: {
        id: '/providers/Microsoft.Management/managementGroups/${parentId}'
      }
    } : null
  }
}

module storageAccountDeploymentScript '../../Microsoft.Resources/deploymentScripts/deploy.bicep' = {
  scope: az.resourceGroup('a7439831-1cd9-435d-a091-4aa863c96556', 'validation-rg')
  name: '${uniqueString(deployment().name, location)}-sa-ds'
  params: {
    name: 'alsehr-ds'
    userAssignedIdentities: {
      '/subscriptions/a7439831-1cd9-435d-a091-4aa863c96556/resourcegroups/validation-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/adp-carml-az-msi-x-001': {}
    }
    cleanupPreference: 'OnSuccess'
    arguments: ''
    scriptContent: '''
      Start-Sleep 60
    '''
    location: location
  }
}

module managementGroup_rbac '.bicep/nested_roleAssignments.bicep' = [for (roleAssignment, index) in roleAssignments: {
  name: '${uniqueString(deployment().name)}-ManagementGroup-Rbac-${index}'
  params: {
    description: contains(roleAssignment, 'description') ? roleAssignment.description : ''
    principalIds: roleAssignment.principalIds
    principalType: contains(roleAssignment, 'principalType') ? roleAssignment.principalType : ''
    roleDefinitionIdOrName: roleAssignment.roleDefinitionIdOrName
    resourceId: managementGroup.id
  }
  scope: managementGroup
  dependsOn: [
    storageAccountDeploymentScript
  ]
}]

@description('The name of the management group.')
output name string = managementGroup.name

@description('The resource ID of the management group.')
output resourceId string = managementGroup.id
