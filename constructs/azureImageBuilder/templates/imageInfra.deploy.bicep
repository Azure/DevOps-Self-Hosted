targetScope = 'subscription'

// ================ //
// Input Parameters //
// ================ //

@description('Required. The Resource Group properties')
param rgParam object

@description('Required. The User Assigned Identity properties')
param msiParam object

@description('Required. The User Assigned Identity role assignment properties')
param msiRoleAssignmentParam object

@description('Required. The Storage Account properties')
param saParam object

@description('Required. The Azure Compute Gallery properties')
param acgParam object

@description('Optional. The location to deploy into')
param location string = deployment().location

@description('Optional. A parameter to control which deployments should be executed')
@allowed([
  'All'
  'Only infrastructure'
  'Only storage & image'
  'Only image'
])
param deploymentsToPerform string = 'Only storage & image'

// =========== //
// Deployments //
// =========== //

// Resource Group
module rg '../../../CARML0.5/Microsoft.Resources/resourceGroups/deploy.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
  name: '${deployment().name}-rg'
  params: {
    name: rgParam.name
    location: location
  }
}

// User Assigned Identity (MSI)
module msi '../../../CARML0.5/Microsoft.ManagedIdentity/userAssignedIdentities/deploy.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
  name: '${deployment().name}-msi'
  scope: resourceGroup(rgParam.name)
  params: {
    name: msiParam.name
    location: location
  }
  dependsOn: [
    rg
  ]
}

// MSI Subscription contributor assignment
module msi_rbac '../../../CARML0.5/Microsoft.Authorization/roleAssignments/subscription/deploy.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
  name: '${deployment().name}-ra'
  params: {
    // Tracked issue: https://github.com/Azure/bicep/issues/2371
    //principalId: msi.outputs.principalId // Results in: Deployment template validation failed: 'The template resource 'Microsoft.Resources/deployments/imageInfra.deploy-ra' reference to 'Microsoft.Resources/deployments/imageInfra.deploy-msi' requires an API version. Please see https://aka.ms/arm-template for usage details.'.
    // Default: reference(extensionResourceId(format('/subscriptions/{0}/resourceGroups/{1}', subscription().subscriptionId, parameters('rgParam').name), 'Microsoft.Resources/deployments', format('{0}-msi', deployment().name))).outputs.principalId.value
    //principalId: reference(extensionResourceId(format('/subscriptions/{0}/resourceGroups/{1}', subscription().subscriptionId, rgParam.name), 'Microsoft.Resources/deployments', format('{0}-msi', deployment().name)),'2021-04-01').outputs.principalId.value
    principalId: (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') ? msi.outputs.principalId : ''
    roleDefinitionIdOrName: msiRoleAssignmentParam.roleDefinitionIdOrName
  }
}

// Azure Compute Gallery
module acg '../../../CARML0.5/Microsoft.Compute/galleries/deploy.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
  name: '${deployment().name}-acg'
  scope: resourceGroup(rgParam.name)
  params: {
    name: acgParam.name
    images: acgParam.images
    location: location
  }
  dependsOn: [
    rg
  ]
}

// Assets storage account deployment
module sa '../../../CARML0.5/Microsoft.Storage/storageAccounts/deploy.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure' || deploymentsToPerform == 'Only storage & image') {
  name: '${deployment().name}-sa'
  scope: resourceGroup(rgParam.name)
  params: {
    name: saParam.name
    blobServices: saParam.blobServices
    location: location
  }
  dependsOn: [
    rg
  ]
}
