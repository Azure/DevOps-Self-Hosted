targetScope = 'subscription'

// ================ //
// Input Parameters //
// ================ //

// Resource Group Parameters
@description('Optional. The name of the Resource Group.')
param resourceGroupName string = 'agents-vmss-rg'

// User Assigned Identity (MSI) Parameters
@description('Optional. The name of the Managed Identity.')
param managedIdentityName string = 'aibMsi'

// Azure Compute Gallery Parameters
@description('Required. The name of the Azure Compute Gallery.')
param computeGalleryName string

@description('Optional. The Image Definitions in the Azure Compute Gallery.')
param computeGalleryImageDefinitions array = [
  // Linux Example
  {
    hyperVGeneration: 'V2'
    name: 'linux-sid'
    osType: 'Linux'
    publisher: 'devops'
    offer: 'devops_linux'
    sku: 'devops_linux_az'
  }
  // Windows Example
  {
    name: 'windows-sid'
    osType: 'Windows'
    publisher: 'devops'
    offer: 'devops_windows'
    sku: 'devops_windows_az'
  }
]

// Storage Account Parameters
@description('Required. The name of the storage account.')
param storageAccountName string

@description('Optional. The name of container in the Storage Account.')
param storageAccountContainerName string = 'aibscripts'

// Shared Parameters
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
module rg '../../../CARML0.9/Microsoft.Resources/resourceGroups/deploy.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
  name: '${deployment().name}-rg'
  params: {
    name: resourceGroupName
    location: location
  }
}

// User Assigned Identity (MSI)
module msi '../../../CARML0.9/Microsoft.ManagedIdentity/userAssignedIdentities/deploy.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
  name: '${deployment().name}-msi'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: managedIdentityName
    location: location
  }
  dependsOn: [
    rg
  ]
}

// MSI Subscription contributor assignment
module msi_rbac '../../../CARML0.9/Microsoft.Authorization/roleAssignments/subscription/deploy.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
  name: '${deployment().name}-ra'
  params: {
    // Tracked issue: https://github.com/Azure/bicep/issues/2371
    //principalId: msi.outputs.principalId // Results in: Deployment template validation failed: 'The template resource 'Microsoft.Resources/deployments/imageInfra.deploy-ra' reference to 'Microsoft.Resources/deployments/imageInfra.deploy-msi' requires an API version. Please see https://aka.ms/arm-template for usage details.'.
    // Default: reference(extensionResourceId(format('/subscriptions/{0}/resourceGroups/{1}', subscription().subscriptionId, parameters('rgParam').name), 'Microsoft.Resources/deployments', format('{0}-msi', deployment().name))).outputs.principalId.value
    //principalId: reference(extensionResourceId(format('/subscriptions/{0}/resourceGroups/{1}', subscription().subscriptionId, resourceGroupName), 'Microsoft.Resources/deployments', format('{0}-msi', deployment().name)),'2021-04-01').outputs.principalId.value
    principalId: (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') ? msi.outputs.principalId : ''
    roleDefinitionIdOrName: 'Contributor'
    location: location
  }
}

// Azure Compute Gallery
module acg '../../../CARML0.9/Microsoft.Compute/galleries/deploy.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
  name: '${deployment().name}-acg'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: computeGalleryName
    images: computeGalleryImageDefinitions
    location: location
  }
  dependsOn: [
    rg
  ]
}

// Assets storage account deployment
module sa '../../../CARML0.9/Microsoft.Storage/storageAccounts/deploy.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure' || deploymentsToPerform == 'Only storage & image') {
  name: '${deployment().name}-sa'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: storageAccountName
    blobServices: {
      containers: [
        {
          name: storageAccountContainerName
          publicAccess: 'None'
        }
      ]
    }
    location: location
  }
  dependsOn: [
    rg
  ]
}
