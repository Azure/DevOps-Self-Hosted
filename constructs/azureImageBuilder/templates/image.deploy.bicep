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

@description('Required. The Image Definitions in the Azure Compute Gallery.')
param computeGalleryImageDefinitions array

// Storage Account Parameters
@description('Required. The name of the storage account.')
param storageAccountName string

@description('Optional. The name of the storage account.')
param deploymentScriptStorageAccountName string = '${storageAccountName}ds'

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
param virtualNetworkSubnetAddressPrefix string = cidrSubnet(virtualNetworkAddressPrefix, 24, 0)

@description('Optional. The address space of the Virtual Network Subnet used by the deployment script.')
param virtualNetworkDeploymentScriptSubnetAddressPrefix string = cidrSubnet(virtualNetworkAddressPrefix, 24, 1)

// Deployment Script Parameters
@description('Optional. The name of the Deployment Script to trigger the Image Template baking.')
param storageDeploymentScriptName string = 'triggerUpload-storage'

@description('Optional. The files to upload to the Assets Storage Account. The syntax of each item should be like: { name: \'script_LinuxInstallPowerShell_sh\' \n value: loadTextContent(\'../scripts/Uploads/linux/LinuxInstallPowerShell.sh\') }')
param storageAccountFilesToUpload object = {}

@description('Optional. The name of the Deployment Script to trigger the image tempalte baking.')
param imageTemplateDeploymentScriptName string = 'triggerBuild-imageTemplate'

// Image Template Parameters
@description('Optional. The name of the Image Template.')
param imageTemplateName string = 'aibIt'

@description('Required. The image source to use for the Image Template.')
param imageTemplateImageSource object

@description('Required. The customization steps to use for the Image Template.')
param imageTemplateCustomizationSteps array

@description('Required. The name of Image Definition of the Azure Compute Gallery to host the new image version.')
param imageTemplateComputeGalleryImageDefinitionName string

@description('Optional. The name of the Resource Group to deploy the Image Template resources into.')
param imageTemplateResourceGroupName string = ''

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
module rg '../../../CARML0.11/resources/resource-group/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
  name: '${deployment().name}-rg'
  params: {
    name: resourceGroupName
    location: location
  }
}

// User Assigned Identity (MSI)
module msi '../../../CARML0.11/managed-identity/user-assigned-identity/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure' || deploymentsToPerform == 'Only storage & image') {
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
module msi_rbac '../../../CARML0.11/authorization//role-assignment/subscription/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
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
module azureComputeGallery '../../../CARML0.11/compute/gallery/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure' || deploymentsToPerform == 'Only storage & image' || deploymentsToPerform == 'Only image') {
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
module nsg '../../../CARML0.11/network/network-security-group/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
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
        name: virtualNetworkSubnetName
        addressPrefix: virtualNetworkSubnetAddressPrefix
        // TODO: Remove once https://github.com/Azure/bicep/issues/6540 is resolved and Private Endpoints are enabled
        // networkSecurityGroupId: (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') ? nsg.outputs.resourceId : '' // TODO: Check if the extra condition helps mitigating the reference issue
        privateLinkServiceNetworkPolicies: 'Disabled'
        // serviceEndpoints: [
        //   {
        //     service: 'Microsoft.Storage'
        //   }
        // ]
      }
      {
        name: 'deploymentSsriptSubnet'
        addressPrefix: virtualNetworkDeploymentScriptSubnetAddressPrefix
        serviceEndpoints: [
          {
            service: 'Microsoft.Storage'
          }
        ]
        delegations: [
          {
            name: 'deploymentScript'
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

// Assets Storage Account Private DNS Zone
module privateDNSZone '../../../CARML0.11/network/private-dns-zone/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure') {
  name: '${deployment().name}-prvDNSZone'
  scope: resourceGroup(resourceGroupName)
  #disable-next-line explicit-values-for-loc-params // The location is 'global'
  params: {
    name: 'privatelink.blob.${environment().suffixes.storage}'
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: vnet.outputs.resourceId
      }
    ]
  }
  dependsOn: [
    rg
  ]
}

// Assets Storage Account
module storageAccount '../../../CARML0.11/storage/storage-account/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure' || deploymentsToPerform == 'Only storage & image') {
  name: '${deployment().name}-sa'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: storageAccountName
    allowSharedKeyAccess: false
    blobServices: {
      containers: [
        {
          name: storageAccountContainerName
          publicAccess: 'None'
          roleAssignments: [
            {
              // Allow MSI to access storage account container files to upload files
              roleDefinitionIdOrName: 'Storage Blob Data Contributor'
              // roleDefinitionIdOrName: 'Storage Blob Data Owner'
              principalIds: [
                msi.outputs.principalId
              ]
              principalType: 'ServicePrincipal'
            }
          ]
        }
      ]
    }
    roleAssignments: [
      {
        // Allow MSI to leverage the storage account for private networking
        // ref: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-script-bicep#access-private-virtual-network
        roleDefinitionIdOrName: storageFileDataPrivilegedContributor.id // Storage File Data Priveleged Contributor
        principalIds: [
          msi.outputs.principalId
        ]
        principalType: 'ServicePrincipal'
      }
    ]
    location: location
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    privateEndpoints: [
      {
        service: 'blob'
        subnetResourceId: vnet.outputs.subnetResourceIds[0]
        privateDnsZoneGroup: {
          privateDNSResourceIds: [
            privateDNSZone.outputs.resourceId
          ]
        }
      }
    ]
  }
  dependsOn: [
    rg
  ]
}

resource storageFileDataPrivilegedContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '69566ab7-960f-475b-8e7c-b3118f30c6bd' // Storage File Data Priveleged Contributor for Deployment Script MSI
  scope: tenant()
}

// Deployment script storage account
module storageAccountDeploymentScript '../../../CARML0.11/storage/storage-account/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only infrastructure' || deploymentsToPerform == 'Only storage & image') {
  name: '${deployment().name}-sa-ds'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: deploymentScriptStorageAccountName
    allowSharedKeyAccess: false
    roleAssignments: [
      {
        // Allow MSI to leverage the storage account for private networking
        // ref: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-script-bicep#access-private-virtual-network
        roleDefinitionIdOrName: storageFileDataPrivilegedContributor.id // Storage File Data Priveleged Contributor
        principalIds: [
          msi.outputs.principalId
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
          action: 'Allow'
          id: vnet.outputs.subnetResourceIds[1]
        }
      ]
    }
  }
  dependsOn: [
    rg
  ]
}

// Upload storage account files
module storageAccount_upload '../../../CARML0.11/resources/deployment-script/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only storage & image' || deploymentsToPerform == 'Only image') {
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
    storageAccountResourceId: storageAccountDeploymentScript.outputs.resourceId
    subnetIds: [
      vnet.outputs.subnetResourceIds[1]
    ]
  }
}

// Image template
module imageTemplate '../../../CARML0.11/virtual-machine-images/image-template/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only storage & image' || deploymentsToPerform == 'Only image') {
  name: '${deployment().name}-it'
  scope: resourceGroup(resourceGroupName)
  params: {
    customizationSteps: imageTemplateCustomizationSteps
    imageSource: imageTemplateImageSource
    name: imageTemplateName
    userMsiName: msi.outputs.name
    userMsiResourceGroup: msi.outputs.resourceGroupName
    sigImageDefinitionId: az.resourceId(split(azureComputeGallery.outputs.resourceId, '/')[2], split(azureComputeGallery.outputs.resourceId, '/')[4], 'Microsoft.Compute/galleries/images', azureComputeGallery.outputs.name, imageTemplateComputeGalleryImageDefinitionName)
    subnetId: vnet.outputs.subnetResourceIds[0]
    location: location
    stagingResourceGroup: imageTemplateResourceGroupName
  }
  dependsOn: [
    storageAccount_upload
  ]
}

// Deployment script to trigger image build
module imageTemplate_trigger '../../../CARML0.11/resources/deployment-script/main.bicep' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only storage & image' || deploymentsToPerform == 'Only image') {
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
    imageTemplate
  ]
}

@description('The generated name of the image template.')
output imageTemplateName string = imageTemplate.outputs.name
