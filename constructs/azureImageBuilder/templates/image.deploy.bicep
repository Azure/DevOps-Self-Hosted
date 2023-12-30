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

@description('Required. The Image Definitions in the Azure Compute Gallery.')
param computeGalleryImageDefinitions array

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

@description('Optional. The name of the Image Template Virtual Network Subnet to create.')
param imageSubnetName string = 'subnet-it'

@description('Optional. The address space of the Virtual Network Subnet.')
param virtualNetworkSubnetAddressPrefix string = cidrSubnet(virtualNetworkAddressPrefix, 24, 0)

@description('Optional. The name of the Image Template Virtual Network Subnet to create.')
param deploymentScriptSubnet string = 'subnet-ds'

@description('Optional. The address space of the Virtual Network Subnet used by the deployment script.')
param virtualNetworkDeploymentScriptSubnetAddressPrefix string = cidrSubnet(virtualNetworkAddressPrefix, 24, 1)

// Deployment Script Parameters
@description('Optional. The name of the Deployment Script to trigger the Image Template baking.')
param storageDeploymentScriptName string = 'ds-triggerUpload-storage'

@description('Optional. The files to upload to the Assets Storage Account. The syntax of each item should be like: { name: \'script_LinuxInstallPowerShell_sh\' \n value: loadTextContent(\'../scripts/uploads/linux/LinuxInstallPowerShell.sh\') }')
param storageAccountFilesToUpload object = {}

@description('Optional. The name of the Deployment Script to trigger the image tempalte baking.')
param imageTemplateDeploymentScriptName string = 'ds-triggerBuild-imageTemplate'

// Image Template Parameters
@description('Optional. The name of the Image Template.')
param imageTemplateName string = 'it-aib'

@description('Required. The image source to use for the Image Template.')
param imageTemplateImageSource object

@description('Required. The customization steps to use for the Image Template.')
param imageTemplateCustomizationSteps array

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

// Resource Groups
module rg '../../../CARML0.11/resources/resource-group/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
  name: '${deployment().name}-rg'
  params: {
    name: resourceGroupName
    location: location
  }
}

// Always deployed as both an infra element & needed as a staging resource group for image building
module imageTemplateRg '../../../CARML0.11/resources/resource-group/main.bicep' = {
  name: '${deployment().name}-rg'
  params: {
    name: imageTemplateResourceGroupName
    location: location
  }
}

// User Assigned Identity (MSI)
// Always deployed as both an infra element & its output is neeeded for image building
module dsMsi '../../../CARML0.11/managed-identity/user-assigned-identity/main.bicep' = {
  name: '${deployment().name}-ds-msi'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: deploymentScriptManagedIdentityName
    location: location
  }
  dependsOn: [
    rg
  ]
}

module imageMSI '../../../CARML0.11/managed-identity/user-assigned-identity/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
  name: '${deployment().name}-image-msi'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: imageManagedIdentityName
    location: location
  }
  dependsOn: [
    rg
  ]
}

// MSI Subscription contributor assignment
module imageMSI_rbac '../../../CARML0.11/authorization//role-assignment/subscription/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
  name: '${deployment().name}-ra'
  params: {
    // TODO: Tracked issue: https://github.com/Azure/bicep/issues/2371
    //principalId: imageMSI.outputs.principalId // Results in: Deployment template validation failed: 'The template resource 'Microsoft.Resources/deployments/image.deploy-ra' reference to 'Microsoft.Resources/deployments/image.deploy-msi' requires an API version. Please see https://aka.ms/arm-template for usage details.'.
    // Default: reference(extensionResourceId(format('/subscriptions/{0}/resourceGroups/{1}', subscription().subscriptionId, parameters('rgParam').name), 'Microsoft.Resources/deployments', format('{0}-msi', deployment().name))).outputs.principalId.value
    //principalId: reference(extensionResourceId(format('/subscriptions/{0}/resourceGroups/{1}', subscription().subscriptionId, resourceGroupName), 'Microsoft.Resources/deployments', format('{0}-msi', deployment().name)),'2021-04-01').outputs.principalId.value
    principalId: (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') ? imageMSI.outputs.principalId : ''
    roleDefinitionIdOrName: 'Contributor'
    location: location
  }
}

// Azure Compute Gallery
module azureComputeGallery '../../../CARML0.11/compute/gallery/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
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

// Image Template Virtual Network
module vnet '../../../CARML0.11/network/virtual-network/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
  name: '${deployment().name}-vnet'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: virtualNetworkName
    addressPrefixes: [
      virtualNetworkAddressPrefix
    ]
    subnets: [
      {
        name: imageSubnetName
        addressPrefix: virtualNetworkSubnetAddressPrefix
        // TODO: Remove once https://github.com/Azure/bicep/issues/6540 is resolved and Private Endpoints are enabled
        privateLinkServiceNetworkPolicies: 'Disabled' // Required if using Azure Image Builder with existing VNET
        serviceEndpoints: [
          {
            service: 'Microsoft.Storage'
          }
        ]
      }
      {
        name: deploymentScriptSubnet
        addressPrefix: virtualNetworkDeploymentScriptSubnetAddressPrefix
        serviceEndpoints: [
          {
            service: 'Microsoft.Storage'
          }
        ]
        delegations: [
          {
            name: 'Microsoft.ContainerInstance.containerGroups'
            properties: {
              serviceName: 'Microsoft.ContainerInstance/containerGroups'
            }
          }
        ]
      }
    ]
    location: location
  }
  dependsOn: [
    rg
  ]
}

// Assets Storage Account
module assetsStorageAccount '../../../CARML0.11/storage/storage-account/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
  name: '${deployment().name}-files-sa'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: assetsStorageAccountName
    allowSharedKeyAccess: false // Keys not needed if MSI is granted access
    location: location
    blobServices: {
      containers: [
        {
          name: assetsStorageAccountContainerName
          publicAccess: 'None'
          roleAssignments: [
            {
              // Allow Infra MSI to access storage account container to upload files - DO NOT REMOVE
              roleDefinitionIdOrName: 'Storage Blob Data Contributor'
              principalIds: [
                (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') ? dsMsi.outputs.principalId : '' // Requires condition als Bicep will otherwise try to resolve the null reference
              ]
              principalType: 'ServicePrincipal'
            }
            {
              // Allow image MSI to access storage account container to read files - DO NOT REMOVE
              roleDefinitionIdOrName: 'Storage Blob Data Reader'
              principalIds: [
                (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') ? imageMSI.outputs.principalId : '' // Requires condition als Bicep will otherwise try to resolve the null reference
              ]
              principalType: 'ServicePrincipal'
            }
          ]
        }
      ]
    }
  }
  dependsOn: [
    rg
  ]
}

////////////////////
// TEMP RESOURCES //
////////////////////

// Deployment scripts & their storage account
// Role required for deployment script to be able to use a storage account via private networking
resource storageFileDataPrivilegedContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '69566ab7-960f-475b-8e7c-b3118f30c6bd' // Storage File Data Priveleged Contributor
  scope: tenant()
}

module dsStorageAccount '../../../CARML0.11/storage/storage-account/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
  name: '${deployment().name}-ds-sa'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: deploymentScriptStorageAccountName
    allowSharedKeyAccess: true // May not be disabled to allow deployment script to access storage account files
    roleAssignments: [
      {
        // Allow MSI to leverage the storage account for private networking of container instance
        // ref: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-script-bicep#access-private-virtual-network
        roleDefinitionIdOrName: storageFileDataPrivilegedContributor.id // Storage File Data Priveleged Contributor
        principalIds: [
          (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') ? dsMsi.outputs.principalId : '' // Requires condition als Bicep will otherwise try to resolve the null reference
        ]
        principalType: 'ServicePrincipal'
      }
    ]
    location: location
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          // Allow deployment script to use storage account for private networking of container instance
          action: 'Allow'
          id: az.resourceId(subscription().subscriptionId, resourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, deploymentScriptSubnet)
        }
      ]
    }
  }
  dependsOn: [
    rg
    vnet
  ]
}

// Upload storage account files
module storageAccount_upload '../../../CARML0.11/resources/deployment-script/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure' || deploymentsToPerform == 'Only storage & image') {
  name: '${deployment().name}-storage-upload-ds'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: '${storageDeploymentScriptName}-${formattedTime}'
    userAssignedIdentities: {
      '${az.resourceId(subscription().subscriptionId, resourceGroupName, 'Microsoft.ManagedIdentity/userAssignedIdentities', deploymentScriptManagedIdentityName)}': {}
    }
    scriptContent: loadTextContent('../scripts/storage/Set-StorageContainerContentByEnvVar.ps1')
    environmentVariables: storageAccountFilesToUpload
    arguments: ' -StorageAccountName "${assetsStorageAccountName}" -TargetContainer "${assetsStorageAccountContainerName}"'
    timeout: 'PT30M'
    cleanupPreference: 'Always'
    location: location
    storageAccountName: deploymentScriptStorageAccountName
    subnetIds: [
      az.resourceId(subscription().subscriptionId, resourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, deploymentScriptSubnet)
    ]
  }
  dependsOn: [
    rg
    dsMsi
    vnet
    dsStorageAccount
    assetsStorageAccount
  ]
}

// Image template
module imageTemplate '../../../CARML0.11/virtual-machine-images/image-template/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only storage & image' || deploymentsToPerform == 'Only image') {
  name: '${deployment().name}-it'
  scope: resourceGroup(resourceGroupName)
  params: {
    customizationSteps: imageTemplateCustomizationSteps
    imageSource: imageTemplateImageSource
    name: imageTemplateName
    userMsiName: imageManagedIdentityName
    userMsiResourceGroup: resourceGroupName
    sigImageDefinitionId: az.resourceId(subscription().subscriptionId, resourceGroupName, 'Microsoft.Compute/galleries/images', computeGalleryName, imageTemplateComputeGalleryImageDefinitionName)
    subnetId: az.resourceId(subscription().subscriptionId, resourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, imageSubnetName)
    location: location
    stagingResourceGroup: imageTemplateRg.outputs.resourceId
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Contributor'
        principalIds: [
          dsMsi.outputs.principalId // Allow deployment script to trigger image build
        ]
        principalType: 'ServicePrincipal'
      }
    ]
  }
  dependsOn: [
    rg
    azureComputeGallery
    imageMSI
    storageAccount_upload
    azureComputeGallery
  ]
}

// Deployment script to trigger image build
module imageTemplate_trigger '../../../CARML0.11/resources/deployment-script/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only storage & image' || deploymentsToPerform == 'Only image') {
  name: '${deployment().name}-imageTemplate-trigger-ds'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: '${imageTemplateDeploymentScriptName}-${formattedTime}-${(deploymentsToPerform == 'All' || deploymentsToPerform == 'Only storage & image' || deploymentsToPerform == 'Only image') ? imageTemplate.outputs.name : ''}' // Requires condition als Bicep will otherwise try to resolve the null reference
    userAssignedIdentities: {
      '${az.resourceId(subscription().subscriptionId, resourceGroupName, 'Microsoft.ManagedIdentity/userAssignedIdentities', deploymentScriptManagedIdentityName)}': {}
    }
    scriptContent: (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only storage & image' || deploymentsToPerform == 'Only image') ? imageTemplate.outputs.runThisCommand : '' // Requires condition als Bicep will otherwise try to resolve the null reference
    timeout: 'PT30M'
    cleanupPreference: 'Always'
    location: location
    storageAccountName: deploymentScriptStorageAccountName
    subnetIds: [
      az.resourceId(subscription().subscriptionId, resourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, deploymentScriptSubnet)
    ]
  }
  dependsOn: [
    rg
    dsMsi
    vnet
    dsStorageAccount
  ]
}

@description('The generated name of the image template.')
output imageTemplateName string = (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only storage & image' || deploymentsToPerform == 'Only image') ? imageTemplate.outputs.name : '' // Requires condition als Bicep will otherwise try to resolve the null reference
