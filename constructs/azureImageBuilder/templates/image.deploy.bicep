targetScope = 'subscription'

// ================ //
// Input Parameters //
// ================ //

// Resource Group Parameters
@description('Optional. The name of the Resource Group.')
param resourceGroupName string = 'rg-ado-agents'

@description('Optional. The name of the Resource Group to deploy the Image Template resources into.')
param imageTemplateResourceGroupName string = '${resourceGroupName}-image-build'

// User Assigned Identity (MSI) Parameters
@description('Optional. The name of the Managed Identity used by deployment scripts.')
param deploymentScriptManagedIdentityName string = 'msi-ds'

@description('Optional. The name of the Managed Identity used by the Azure Image Builder.')
param imageManagedIdentityName string = 'msi-aib'

// Azure Compute Gallery Parameters
@description('Required. The name of the Azure Compute Gallery.')
param computeGalleryName string

import { imageType } from 'br/public:avm/res/compute/gallery:0.9.2'
@description('Required. The Image Definitions in the Azure Compute Gallery.')
param computeGalleryImageDefinitions imageType[]

// Storage Account Parameters
@description('Required. The name of the storage account.')
param assetsStorageAccountName string

@description('Optional. The name of the storage account.')
param deploymentScriptStorageAccountName string = '${assetsStorageAccountName}ds'

@description('Optional. The name of container in the Storage Account.')
param assetsStorageAccountContainerName string = 'aibscripts'

// Virtual Network Parameters
@description('Optional. The name of the Virtual Network.')
param virtualNetworkName string = 'vnet-it'

@description('Optional. The address space of the Virtual Network.')
param virtualNetworkAddressPrefix string = '10.0.0.0/16'

@description('Optional. The name of the Virtual Network Subnet to create and use for Azure Container Instances for isolated builds. For more information please refer to [docs](https://learn.microsoft.com/en-us/azure/virtual-machines/security-isolated-image-builds-image-builder#bring-your-own-build-vm-subnet-and-bring-your-own-aci-subnet).')
param imageContainerInstanceSubnetName string = 'subnet-ci'

@description('Optional. The address space of the Virtual Network Subnet.')
param virtualNetworkSubnetAddressPrefix string = cidrSubnet(virtualNetworkAddressPrefix, 24, 0)

@description('Optional. The name of the Image Template Virtual Network Subnet to create.')
param imageSubnetName string = 'subnet-it'

@description('Optional. The address space of the Virtual Network Subnet used by the Azure Container Instances for isolated builds. Only relevant if `imageContainerInstanceSubnetName` is not empty.')
param imageContainerInstanceSubnetAddressPrefix string = cidrSubnet(virtualNetworkAddressPrefix, 24, 1)

@description('Optional. The name of the Image Template Virtual Network Subnet to create.')
param deploymentScriptSubnetName string = 'subnet-ds'

@description('Optional. The address space of the Virtual Network Subnet used by the deployment script.')
param virtualNetworkDeploymentScriptSubnetAddressPrefix string = cidrSubnet(virtualNetworkAddressPrefix, 24, 2)

// Deployment Script Parameters
@description('Optional. The name of the Deployment Script to trigger the Image Template baking.')
param storageDeploymentScriptName string = 'ds-triggerUpload-storage'

@description('Optional. The files to upload to the Assets Storage Account.')
param storageAccountFilesToUpload storageAccountFilesToUploadType[]?

@description('Optional. The name of the Deployment Script to trigger the image tempalte baking.')
param imageTemplateDeploymentScriptName string = 'ds-triggerBuild-imageTemplate'

// Image Template Parameters
@description('Optional. The name of the Image Template.')
param imageTemplateName string = 'it-aib'

@description('Required. The image source to use for the Image Template.')
param imageTemplateImageSource resourceInput<'Microsoft.VirtualMachineImages/imageTemplates@2024-02-01'>.properties.source

@description('Required. The customization steps to use for the Image Template.')
param imageTemplateCustomizationSteps resourceInput<'Microsoft.VirtualMachineImages/imageTemplates@2024-02-01'>.properties.customize?

@description('Required. The name of Image Definition of the Azure Compute Gallery to host the new image version.')
param computeGalleryImageDefinitionName string

@description('Optional. Enable/Disable usage telemetry for used AVM modules.')
param enableAVMTelemetry bool = true

@description('Optional. A parameter to control if the deployment should wait for the image build to complete.')
param waitForImageBuild bool = true

@description('Optional. A parameter to control the timeout of the deployment script waiting for the image build.')
param waitForImageBuildTimeout string = 'PT1H'

@description('Optional. The name of the Deployment Script to wait for for the image baking to conclude.')
param waitDeploymentScriptName string = 'ds-wait-imageTemplate-build'

// Shared Parameters
@description('Optional. The location to deploy into')
param resourceLocation string = deployment().location

@description('Optional. A parameter to control which deployments should be executed')
@allowed([
  'All'
  'Only base'
  'Only assets & image'
  'Only image'
])
param deploymentsToPerform string = 'Only assets & image'

// =========== //
// Deployments //
// =========== //

module imageConstruct 'br/public:avm/ptn/virtual-machine-images/azure-image-builder:0.2.0' = {
  name: '${uniqueString(deployment().name, resourceLocation)}-image-construct'
  params: {
    deploymentsToPerform: deploymentsToPerform
    resourceGroupName: resourceGroupName
    location: resourceLocation
    enableTelemetry: enableAVMTelemetry

    computeGalleryImageDefinitionName: computeGalleryImageDefinitionName
    computeGalleryImageDefinitions: computeGalleryImageDefinitions
    computeGalleryName: computeGalleryName

    imageTemplateImageSource: imageTemplateImageSource
    assetsStorageAccountContainerName: assetsStorageAccountContainerName
    assetsStorageAccountName: assetsStorageAccountName
    deploymentScriptManagedIdentityName: deploymentScriptManagedIdentityName
    deploymentScriptStorageAccountName: deploymentScriptStorageAccountName
    imageManagedIdentityName: imageManagedIdentityName

    imageTemplateCustomizationSteps: imageTemplateCustomizationSteps
    imageTemplateDeploymentScriptName: imageTemplateDeploymentScriptName
    imageTemplateName: imageTemplateName
    imageTemplateResourceGroupName: imageTemplateResourceGroupName

    storageAccountFilesToUpload: storageAccountFilesToUpload
    storageDeploymentScriptName: storageDeploymentScriptName

    virtualNetworkAddressPrefix: virtualNetworkAddressPrefix
    virtualNetworkSubnetAddressPrefix: virtualNetworkSubnetAddressPrefix
    imagecontainerInstanceSubnetAddressPrefix: imageContainerInstanceSubnetAddressPrefix
    virtualNetworkDeploymentScriptSubnetAddressPrefix: virtualNetworkDeploymentScriptSubnetAddressPrefix
    virtualNetworkName: virtualNetworkName
    imageSubnetName: imageSubnetName
    imageContainerInstanceSubnetName: imageContainerInstanceSubnetName
    deploymentScriptSubnetName: deploymentScriptSubnetName

    waitDeploymentScriptName: waitDeploymentScriptName
    waitForImageBuild: waitForImageBuild
    waitForImageBuildTimeout: waitForImageBuildTimeout
  }
}

// =============== //
//   Definitions   //
// =============== //

type storageAccountFilesToUploadType = {
  @description('Required. The name of the environment variable.')
  name: string

  @description('Required. The value of the secure environment variable.')
  @secure()
  secureValue: string?

  @description('Required. The value of the environment variable.')
  value: string?
}
