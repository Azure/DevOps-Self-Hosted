targetScope = 'subscription'

// ================ //
// Input Parameters //
// ================ //

// Resource Group Parameters
@description('Optional. The name of the Resource Group.')
param resourceGroupName string = 'rg-ado-agents'

// Network Security Group Parameters
@description('Optional. The name of the Network Security Group.')
param networkSecurityGroupName string = 'nsg-vmss'

// Virtual Network Parameters
@description('Optional. The name of the Virtual Network.')
param virtualNetworkName string = 'vnet-vmss'

@description('Optional. The address space of the Virtual Network.')
param virtualNetworkAddressPrefix string = '10.0.0.0/16'

@description('Optional. The subnets to create in the Virtual Network.')
param virtualNetworkSubnets array = [
  {
    name: 'vmsssubnet'
    addressPrefix: '10.0.0.0/24' // 10.0.0.0 - 10.0.0.255
    delegation: 'Microsoft.DevOpsInfrastructure/pools'
  }
]

// Virtual Machine Scale Set Parameters
// @description('Optional. The name of the Virtual Machine Scale Set.')
// param virtualMachineScaleSetName string = 'vmss-agents'

// @description('Optional. The Virtual Machine name prefix of the Virtual Machine Scale Set.')
// param virtualMachineScaleSetVMNamePrefix string = 'vmssvm'

// @description('Required. The OS type of the Virtual Machine Scale Set.')
// param virtualMachineScaleSetOsType string

// @description('Optional. The SKU Size of the Virtual Machine Scale Set.')
// param virtualMachineScaleSetSKUSize string = 'Standard_B2s'

// @description('Required. Disable/Enable password authentication of the Virtual Machine Scale Set.')
// param virtualMachineScaleSetDisablePasswordAuthentication bool

// @description('Optional. The Public Keys of the Virtual Machine Scale Set.')
// param virtualMachineScaleSetPublicKeys array = []

// @description('Optional. The admin password of the Virtual Machine Scale Set.')
// @secure()
// param virtualMachineScaleSetAdminPassword string = ''

// @description('Optional. The admin user name of the Virtual Machine Scale Set.')
// param virtualMachineScaleSetAdminUserName string = 'scaleSetAdmin'

@description('Required. The name of the Azure Compute Gallery that hosts the image of the Virtual Machine Scale Set.')
param virtualMachineScaleSetComputeGalleryName string

@description('Required. The name of Image Definition of the Azure Compute Gallery that hosts the image of the Virtual Machine Scale Set.')
param virtualMachineScaleSetComputeGalleryImageDefinitionName string

@description('Optional. The version of the image to use in the Virtual Machine Scale Set.')
param virtualMachineScaleSetImageVersion string = 'latest'

param poolName string
param organizationName string
param projectNames string[]?
param devCenterName string
param devCenterProjectName string
param devOpsInfrastructureEnterpriseApplicationObjectId string

// Shared Parameters
@description('Optional. The location to deploy into')
param location string = deployment().location

@description('Optional. A parameter to control which deployments should be executed')
@allowed([
  'All'
  'Only Scale Set'
])
param deploymentsToPerform string = 'All'

// =========== //
// Deployments //
// =========== //

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = if (deploymentsToPerform == 'All' || deploymentsToPerform == 'Only base') {
  name: resourceGroupName
  location: location
}

// Network Security Group
module nsg 'br/public:avm/res/network/network-security-group:0.3.0' = if (deploymentsToPerform == 'All') {
  name: '${deployment().name}-nsg'
  scope: rg
  params: {
    name: networkSecurityGroupName
    location: location
  }
}

// Virtual Network
module vnet 'br/public:avm/res/network/virtual-network:0.4.0' = if (deploymentsToPerform == 'All') {
  name: '${deployment().name}-vnet'
  scope: rg
  params: {
    name: virtualNetworkName
    addressPrefixes: [
      virtualNetworkAddressPrefix
    ]
    subnets: virtualNetworkSubnets
    location: location
  }
}

// Image Version
// resource computeGallery 'Microsoft.Compute/galleries@2022-03-03' existing = {
//   scope: rg

//   name: virtualMachineScaleSetComputeGalleryName

//   resource imageDefinition 'images@2022-03-03' existing = {
//     name: virtualMachineScaleSetComputeGalleryImageDefinitionName

//     resource imageVersion 'versions@2022-03-03' existing = {
//       name: virtualMachineScaleSetImageVersion
//     }
//   }
// }

module pool 'nestedPool.bicep' = {
  scope: rg
  name: '${deployment().name}-pool'
  params: {
    location: location
    // computeImageResourceId: computeGallery::imageDefinition::imageVersion.id
    devCenterName: devCenterName
    devCenterProjectName: devCenterProjectName
    maximumConcurrency: 1
    poolName: poolName
    organizationName: organizationName
    projectNames: projectNames
    vnetResourceId: vnet.outputs.resourceId
    subnetName: vnet.outputs.subnetNames[0]
    virtualMachineScaleSetComputeGalleryImageDefinitionName: virtualMachineScaleSetComputeGalleryImageDefinitionName
    virtualMachineScaleSetComputeGalleryName: virtualMachineScaleSetComputeGalleryName
    virtualMachineScaleSetImageVersion: virtualMachineScaleSetImageVersion
    devOpsInfrastructureEnterpriseApplicationObjectId: devOpsInfrastructureEnterpriseApplicationObjectId
  }
}

// Virtual Machine Scale Set
// module vmss 'br/public:avm/res/compute/virtual-machine-scale-set:0.2.2' = {
//   name: '${deployment().name}-vmss'
//   scope: rg
//   params: {
//     name: virtualMachineScaleSetName
//     vmNamePrefix: virtualMachineScaleSetVMNamePrefix
//     skuName: virtualMachineScaleSetSKUSize
//     skuCapacity: 0
//     upgradePolicyMode: 'Manual'
//     vmPriority: 'Regular'
//     osDisk: {
//       createOption: 'fromImage'
//       diskSizeGB: 128
//       managedDisk: {
//         storageAccountType: 'Premium_LRS'
//       }
//     }
//     // orchestrationMode: 'Uniform'
//     // managedIdentities: {
//     //   systemAssigned: true
//     // }
//     osType: virtualMachineScaleSetOsType
//     imageReference: {
//       id: computeGallery::imageDefinition::imageVersion.id
//     }
//     adminUsername: virtualMachineScaleSetAdminUserName
//     disablePasswordAuthentication: virtualMachineScaleSetDisablePasswordAuthentication
//     nicConfigurations: [
//       {
//         nicSuffix: '-nic01'
//         enableAcceleratedNetworking: false
//         ipConfigurations: [
//           {
//             name: 'ipconfig1'
//             properties: {
//               subnet: {
//                 id: vnet.outputs.subnetResourceIds[0]
//               }
//             }
//           }
//         ]
//       }
//     ]
//     scaleInPolicy: {
//       rules: [
//         'Default'
//       ]
//     }
//     adminPassword: virtualMachineScaleSetAdminPassword
//     publicKeys: virtualMachineScaleSetPublicKeys
//     location: location
//   }
// }
