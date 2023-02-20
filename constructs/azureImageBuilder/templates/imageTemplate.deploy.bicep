targetScope = 'subscription'

// ================ //
// Input Parameters //
// ================ //

// Resource Group Parameters
@description('Optional. The name of the Resource Group.')
param resourceGroupName string = 'agents-vmss-rg'

// Dpeloyment Script Parameters
@description('Optional. The name of the Deployment Script to trigger the image tempalte baking.')
param deploymentScriptName string = 'triggerBuild-imageTemplate'

// Image Template Parameters
@description('Optional. The name of the Image Template.')
param imageTemplateName string = 'aibIt'

@description('Optional. The name of the Image Template.')
param imageTemplateManagedIdendityName string = 'aibMsi'

@description('Optional. The name of the Image Template.')
param imageTemplateManagedIdentityResourceGroupName string = resourceGroupName

@description('Required. The image source to use for the Image Template.')
param imageTemplateImageSource object

@description('Required. The customization steps to use for the Image Template.')
param imageTemplateCustomizationSteps array

@description('Required. The name of the Azure Compute Gallery to host the new image version.')
param imageTemplateComputeGalleryName string

@description('Required. The name of Image Definition of the Azure Compute Gallery to host the new image version.')
param imageTemplateComputeGalleryImageDefinitionName string

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

@description('Generated. Do not provide a value! This date value is used to generate a SAS token to access the modules.')
param baseTime string = utcNow()

var formattedTime = replace(replace(replace(baseTime, ':', ''), '-', ''), ' ', '')

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

// Image template
resource computeGallery 'Microsoft.Compute/galleries@2022-03-03' existing = {
  scope: resourceGroup(resourceGroupName)

  name: imageTemplateComputeGalleryName

  resource imageDefinition 'images@2022-03-03' existing = {
    name: imageTemplateComputeGalleryImageDefinitionName
  }
}

module it '../../../CARML0.9/Microsoft.VirtualMachineImages/imageTemplates/deploy.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only storage & image' || deploymentsToPerform == 'Only image') {
  name: '${deployment().name}-it'
  scope: resourceGroup(resourceGroupName)
  params: {
    customizationSteps: imageTemplateCustomizationSteps
    imageSource: imageTemplateImageSource
    name: imageTemplateName
    userMsiName: imageTemplateManagedIdendityName
    userMsiResourceGroup: imageTemplateManagedIdentityResourceGroupName
    sigImageDefinitionId: computeGallery::imageDefinition.id
    location: location
  }
}

resource msi 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  scope: resourceGroup(imageTemplateManagedIdentityResourceGroupName)
  name: imageTemplateManagedIdendityName
}

// Deployment script to trigger image build
module ds '../../../CARML0.9/Microsoft.Resources/deploymentScripts/deploy.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only storage & image' || deploymentsToPerform == 'Only image') {
  name: '${deployment().name}-ds'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: '${deploymentScriptName}-${formattedTime}-${it.outputs.name}'
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
output IMAGETEMPLATENAME string = it.outputs.name
