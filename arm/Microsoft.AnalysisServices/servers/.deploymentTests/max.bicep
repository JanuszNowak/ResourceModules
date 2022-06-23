targetScope = 'subscription'

// ========== //
// Parameters //
// ========== //

@description('Required. The name prefix to inject into all resource names')
param namePrefix string

@description('Optional. The name of the resource group to deploy for a testing purposes')
@maxLength(90)
param resourceGroupName string = '${serviceShort}-ms.analysisservices-servers-rg'

@description('Optional. The location to deploy resources to')
param location string = deployment().location

@description('Optional. A short identifier for the kind of deployment. E.g. "aspar". Should be kept short to not run into resource-name length-constraints')
param serviceShort string = 'asmax'

// =========== //
// Deployments //
// =========== //

// General resources
// =================
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

module managedIdentity 'nestedTemplates/max.parameters.nested.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, location)}-paramNested'
  params: {
    managedIdentityName: 'dep-${namePrefix}-az-msi-${serviceShort}-01'
  }
}

// Diagnostics
// ===========
module diagnosticDependencies '../../../.global/dependencyConstructs/diagnostic.dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, location)}-diagDep'
  params: {
    storageAccountName: 'adp${namePrefix}azsa${serviceShort}01'
    logAnalyticsWorkspaceName: 'adp-${namePrefix}-law-${serviceShort}-01'
    eventHubNamespaceEventHubName: 'adp-${namePrefix}-evh-${serviceShort}-01'
    eventHubNamespaceName: 'adp-${namePrefix}-evhns-${serviceShort}-01'
    location: location
  }
}

// ============== //
// Test Execution //
// ============== //

module servers '../deploy.bicep' = {
  scope: az.resourceGroup(resourceGroupName)
  name: '${uniqueString(deployment().name)}-servers-${serviceShort}'
  params: {
    name: '${namePrefix}azas${serviceShort}001'
    lock: 'CanNotDelete'
    skuName: 'S0'
    skuCapacity: 1
    firewallSettings: {
      firewallRules: [
        {
          firewallRuleName: 'AllowFromAll'
          rangeStart: '0.0.0.0'
          rangeEnd: '255.255.255.255'
        }
      ]
      enablePowerBIService: true
    }
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Reader'
        principalIds: [
          managedIdentity.outputs.managedIdentityPrincipalId
        ]
      }
    ]
    diagnosticLogsRetentionInDays: 7
    diagnosticStorageAccountId: diagnosticDependencies.outputs.storageAccountResourceId
    diagnosticWorkspaceId: diagnosticDependencies.outputs.logAnalyticsWorkspaceResourceId
    diagnosticEventHubAuthorizationRuleId: diagnosticDependencies.outputs.eventHubAuthorizationRuleId
    diagnosticEventHubName: diagnosticDependencies.outputs.eventHubNamespaceEventHubName
    diagnosticLogCategoriesToEnable: [
      'Engine'
      'Service'
    ]
    diagnosticMetricsToEnable: [
      'AllMetrics'
    ]
  }
}