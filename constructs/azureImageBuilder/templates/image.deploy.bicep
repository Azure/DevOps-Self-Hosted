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

// Network Security Group Parameters
@description('Optional. The name of the Network Security Group to create and attach to the Image Template Subnet.')
param networkSecurityGroupName string = 'it-nsg'

// Virtual Network Parameters
@description('Optional. The name of the Virtual Network.')
param virtualNetworkName string = 'it-vnet'

@description('Optional. The address space of the Virtual Network.')
param virtualNetworkAddressPrefix string = '10.0.0.0/16'

@description('Optional. The name of the Image Template Virtual Network Subnet to create.')
param virtualNetworkSubnetName string = 'itsubnet'

@description('Optional. The address space of the Virtual Network Subnet.')
param virtualNetworkSubnetAddressPrefix string = '10.0.0.0/24'

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

// Deployment Script Parameters
@description('Optional. The name of the Deployment Script to trigger the Image Template baking.')
param storageDeploymentScriptName string = 'triggerUpload-storage'

@description('Optional. The files to upload to the Assets Storage Account. The syntax of each item should be like: { name: \'script_LinuxInstallPowerShell_sh\' \n value: loadTextContent(\'../scripts/Uploads/linux/LinuxInstallPowerShell.sh\') }')
param storageAccountFilesToUpload array = []

@description('Optional. The name of the Deployment Script to trigger the image tempalte baking.')
param imageTemplateDeploymentScriptName string = 'triggerBuild-imageTemplate'

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

@description('Required. The name of Image Definition of the Azure Compute Gallery to host the new image version.')
param imageTemplateComputeGalleryImageDefinitionName string

// Shared Parameters

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
    // TODO: Tracked issue: https://github.com/Azure/bicep/issues/2371
    //principalId: msi.outputs.principalId // Results in: Deployment template validation failed: 'The template resource 'Microsoft.Resources/deployments/image.deploy-ra' reference to 'Microsoft.Resources/deployments/image.deploy-msi' requires an API version. Please see https://aka.ms/arm-template for usage details.'.
    // Default: reference(extensionResourceId(format('/subscriptions/{0}/resourceGroups/{1}', subscription().subscriptionId, parameters('rgParam').name), 'Microsoft.Resources/deployments', format('{0}-msi', deployment().name))).outputs.principalId.value
    //principalId: reference(extensionResourceId(format('/subscriptions/{0}/resourceGroups/{1}', subscription().subscriptionId, resourceGroupName), 'Microsoft.Resources/deployments', format('{0}-msi', deployment().name)),'2021-04-01').outputs.principalId.value
    principalId: (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') ? msi.outputs.principalId : ''
    roleDefinitionIdOrName: 'Contributor'
    location: location
  }
}

// Azure Compute Gallery
module azureComputeGallery '../../../CARML0.9/Microsoft.Compute/galleries/deploy.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
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

// Network Security Group
module nsg '../../../CARML0.9/Microsoft.Network/networkSecurityGroups/deploy.bicep' = if (deploymentsToPerform == 'All') {
  name: '${deployment().name}-nsg'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: networkSecurityGroupName
    location: location
  }
  dependsOn: [
    rg
  ]
}

// Image Template Virtual Network
module vnet '../../../CARML0.9/Microsoft.Network/virtualNetworks/deploy.bicep' = if (deploymentsToPerform == 'All') {
  name: '${deployment().name}-vnet'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: virtualNetworkName
    addressPrefixes: [
      virtualNetworkAddressPrefix
    ]
    subnets: [
      {
        name: virtualNetworkSubnetName
        addressPrefix: virtualNetworkSubnetAddressPrefix
        networkSecurityGroupId: nsg.outputs.resourceId
        // TODO: Remove once https://github.com/Azure/bicep/issues/6540 is resolved and Private Endpoints are enabled
        // privateLinkServiceNetworkPolicies: 'Disabled'
        // serviceEndpoints: [
        //   {
        //     service: 'Microsoft.Storage'
        //   }
        // ]
      }
    ]
    location: location
  }
  dependsOn: [
    rg
  ]
}

// Assets Storage Account Private DNS Zone
// TODO: Blocked until https://github.com/Azure/bicep/issues/6540 is resolved
// module privateDNSZone '../../../CARML0.9/Microsoft.Network/privateDnsZones/deploy.bicep' = if (deploymentsToPerform == 'All') {
//   name: '${deployment().name}-prvDNSZone'
//   scope: resourceGroup(resourceGroupName)
//   #disable-next-line explicit-values-for-loc-params // The location is 'global'
//   params: {
//     name: 'privatelink.blob.${environment().suffixes.storage}'
//     virtualNetworkLinks: [
//       {
//         virtualNetworkResourceId: vnet.outputs.resourceId
//       }
//     ]
//   }
//   dependsOn: [
//     rg
//   ]
// }

// Assets Storage Account
module storageAccount '../../../CARML0.9/Microsoft.Storage/storageAccounts/deploy.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure' || deploymentsToPerform == 'Only storage & image') {
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
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          action: 'Allow'
          id: vnet.outputs.subnetResourceIds[0]
        }
      ]
    }
    // TODO: Blocked until https://github.com/Azure/bicep/issues/6540 is implemented
    // privateEndpoints: [
    //   {
    //     service: 'blob'
    //     subnetResourceId: vnet.outputs.subnetResourceIds[0]
    //     privateDnsZoneGroup: {
    //       privateDNSResourceIds: [
    //         privateDNSZone.outputs.resourceId
    //       ]
    //     }
    //   }
    // ]
    roleAssignments: [
      {
        // Allow MSI to access storage account files once uploaded via AAD Auth
        roleDefinitionIdOrName: 'Storage Blob Data Reader'
        principalIds: [
          msi.outputs.principalId
        ]
        principalType: 'ServicePrincipal'
      }
    ]
  }
  dependsOn: [
    rg
  ]
}

// Upload storage account files
// Should be updated to use a subnet once https://github.com/Azure/bicep/issues/6540 is implemented
module storageAccount_upload '../../../CARML0.9/Microsoft.Resources/deploymentScripts/deploy.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only storage & image' || deploymentsToPerform == 'Only image') {
  name: '${deployment().name}-storage-upload-ds'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: '${storageDeploymentScriptName}-${formattedTime}'
    userAssignedIdentities: {
      '${msi.outputs.resourceId}': {}
    }
    scriptContent: loadTextContent('../scripts/storage/Set-StorageContainerContentByEnvVar.ps1')
    environmentVariables: storageAccountFilesToUpload
    arguments: ' -StorageAccountName "${storageAccount.outputs.name}" -TargetContainer "${storageAccountContainerName}"'
    timeout: 'PT30M'
    cleanupPreference: 'Always'
    location: location
  }
}

// Image template
module imageTemplate '../../../CARML0.9/Microsoft.VirtualMachineImages/imageTemplates/deploy.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only storage & image' || deploymentsToPerform == 'Only image') {
  name: '${deployment().name}-it'
  scope: resourceGroup(resourceGroupName)
  params: {
    customizationSteps: imageTemplateCustomizationSteps
    imageSource: imageTemplateImageSource
    name: imageTemplateName
    userMsiName: msi.outputs.name
    userMsiResourceGroup: msi.outputs.resourceGroupName
    sigImageDefinitionId: az.resourceId(subscription().subscriptionId, rg.outputs.name, 'Microsoft.Compute/galleries/images', azureComputeGallery.outputs.name, imageTemplateComputeGalleryImageDefinitionName)
    // TODO: Blocked until https://github.com/Azure/bicep/issues/6540 is resolved
    subnetId: vnet.outputs.subnetResourceIds[0]
    location: location
  }
}

// Deployment script to trigger image build
module imageTemplate_trigger '../../../CARML0.9/Microsoft.Resources/deploymentScripts/deploy.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only storage & image' || deploymentsToPerform == 'Only image') {
  name: '${deployment().name}-imageTemplate-trigger-ds'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: '${imageTemplateDeploymentScriptName}-${formattedTime}-${imageTemplate.outputs.name}'
    userAssignedIdentities: {
      '${msi.outputs.resourceId}': {}
    }
    scriptContent: imageTemplate.outputs.runThisCommand
    timeout: 'PT30M'
    cleanupPreference: 'Always'
    location: location
  }
  dependsOn: [
    storageAccount_upload
  ]
}

@description('The generated name of the image template.')
output imageTemplateName string = imageTemplate.outputs.name
