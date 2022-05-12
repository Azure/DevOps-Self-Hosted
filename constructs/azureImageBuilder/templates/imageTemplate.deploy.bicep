targetScope = 'subscription'

// ================ //
// Input Parameters //
// ================ //

@description('Required. The Resource Group properties')
param rgParam object

@description('Required. The Image Template properties')
param itParam object

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

@description('Generated. Do not provide a value! This date value is used to generate a SAS token to access the modules.')
param baseTime string = utcNow()

var formattedTime = replace(replace(replace(baseTime, ':', ''), '-', ''), ' ', '')

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

// Image template
module it '../../../CARML0.5/Microsoft.VirtualMachineImages/imageTemplates/deploy.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only storage & image' || deploymentsToPerform == 'Only image') {
  name: '${deployment().name}-it'
  scope: resourceGroup(rgParam.name)
  params: {
    customizationSteps: itParam.customizationSteps
    imageSource: itParam.imageSource
    name: itParam.name
    userMsiName: itParam.userMsiName
    userMsiResourceGroup: itParam.userMsiResourceGroup
    sigImageDefinitionId: itParam.sigImageDefinitionId
    location: location
  }
}

resource msi 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  scope: resourceGroup(itParam.userMsiResourceGroup)
  name: itParam.userMsiName
}

// Deployment script to trigger image build
module ds '../../../CARML0.5/Microsoft.Resources/deploymentScripts/deploy.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only storage & image' || deploymentsToPerform == 'Only image') {
  name: '${deployment().name}-ds'
  scope: resourceGroup(rgParam.name)
  params: {
    name: 'triggerBuild-imageTemplate-${formattedTime}-${it.outputs.name}'
    userAssignedIdentities: {
      '${msi.id}': {}
    }
    scriptContent: it.outputs.runThisCommand
    timeout: 'PT30M'
    cleanupPreference: 'Always'
    location: location
  }
}

@description('The generated name of the image template')
output imageTempateName string = it.outputs.name
