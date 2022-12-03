targetScope = 'subscription'

// ================ //
// Input Parameters //
// ================ //

// Resource Group Parameters
@description('Required. The name of the Resource Group.')
param resourceGroupName string

// Network Security Group Parameters
@description('Required. The name of the Network Security Group.')
param networkSecurityGroupName string

// Virtual Network Parameters
@description('Required. The name of the Virtual Network.')
param virtualNetworkName string

@description('Required. The address space of the Virtual Network.')
param virtualNetworkAddressPrefix string

@description('Required. The name of the Virtual Network Subnet.')
param virutalNetworkSubnetName string

@description('Required. The address space of the Virtual Network Subnet.')
param virutalNetworkSubnetAddressPrefix string

// Virtual Machine Scale Set Parameters
@description('Required. The name of the Virtual Machine Scale Set.')
param virtualMachineScaleSetName string

@description('Required. The Virtual Machine name prefix of the Virtual Machine Scale Set.')
param virtualMachineScaleSetVMNamePrefix string

@description('Required. The OS type of the Virtual Machine Scale Set.')
param virtualMachineScaleSetOsType string

@description('Required. The SKU Size of the Virtual Machine Scale Set.')
param virtualMachineScaleSetSKUSize string

@description('Optional. The SKU capacity of the Virtual Machine Scale Set.')
param virtualMachineScaleSetCapacity int = 0

@description('Required. Disable/Enable password authentication of the Virtual Machine Scale Set.')
param virtualMachineScaleSetDisablePasswordAuthentication bool

@description('Optional. The Public Keys of the Virtual Machine Scale Set.')
param virtualMachineScaleSetPublicKeys array = []

@description('Optional. The admin password of the Virtual Machine Scale Set.')
@secure()
param virtualMachineScaleSetAdminPassword string = ''

@description('Required. The admin user name of the Virtual Machine Scale Set.')
param virtualMachineScaleSetAdminUserName string

@description('Required. The name of the Azure Compute Gallery that hosts the image of the Virtual Machine Scale Set.')
param virtualMachineScaleSetComputeGalleryName string

@description('Required. The name of Image Definition of the Azure Compute Gallery that hosts the image of the Virtual Machine Scale Set.')
param virtualMachineScaleSetComputeGalleryImageDefinitionName string

@description('Required. The version of the image to use in the Virtual Machine Scale Set.')
param virtualMachineScaleSetImageVersion string

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
module rg '../../../CARML0.8/Microsoft.Resources/resourceGroups/deploy.bicep' = if (deploymentsToPerform == 'All') {
  name: '${deployment().name}-rg'
  params: {
    name: resourceGroupName
    location: location
  }
}

// Network Security Group
module nsg '../../../CARML0.8/Microsoft.Network/networkSecurityGroups/deploy.bicep' = if (deploymentsToPerform == 'All') {
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

// Virtual Network
module vnet '../../../CARML0.8/Microsoft.Network/virtualNetworks/deploy.bicep' = if (deploymentsToPerform == 'All') {
  name: '${deployment().name}-vnet'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: virtualNetworkName
    addressPrefixes: [
      virtualNetworkAddressPrefix
    ]
    subnets: [
      {
        name: virutalNetworkSubnetName
        addressPrefix: virutalNetworkSubnetAddressPrefix
        networkSecurityGroupName: 'vmss-nsg'
      }
    ]
    location: location
  }
  dependsOn: [
    nsg
    rg
  ]
}

// Image Version
resource computeGallery 'Microsoft.Compute/galleries@2022-03-03' existing = {
  scope: resourceGroup(resourceGroupName)

  name: virtualMachineScaleSetComputeGalleryName

  resource imageDefinition 'images@2022-03-03' existing = {
    name: virtualMachineScaleSetComputeGalleryImageDefinitionName

    resource imageVersion 'versions@2022-03-03' existing = {
      name: virtualMachineScaleSetImageVersion
    }
  }
}

// Virtual Machine Scale Set
module vmss '../../../CARML0.8/Microsoft.Compute/virtualMachineScaleSets/deploy.bicep' = {
  name: '${deployment().name}-vmss'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: virtualMachineScaleSetName
    vmNamePrefix: virtualMachineScaleSetVMNamePrefix
    skuName: virtualMachineScaleSetSKUSize
    skuCapacity: virtualMachineScaleSetCapacity
    upgradePolicyMode: 'Manual'
    vmPriority: 'Regular'
    osDisk: {
      createOption: 'fromImage'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    systemAssignedIdentity: true
    osType: virtualMachineScaleSetOsType
    imageReference: {
      id: computeGallery::imageDefinition::imageVersion.id
    }
    adminUsername: virtualMachineScaleSetAdminUserName
    disablePasswordAuthentication: virtualMachineScaleSetDisablePasswordAuthentication
    nicConfigurations: [
      {
        nicSuffix: '-nic01'
        enableAcceleratedNetworking: false
        ipConfigurations: [
          {
            name: 'ipconfig1'
            properties: {
              subnet: {
                id: vnet.outputs.subnetResourceIds[0]
              }
            }
          }
        ]
      }
    ]
    scaleInPolicy: {
      rules: [
        'Default'
      ]
    }
    adminPassword: virtualMachineScaleSetAdminPassword
    publicKeys: virtualMachineScaleSetPublicKeys
    location: location
  }
  dependsOn: [
    vnet
  ]
}
