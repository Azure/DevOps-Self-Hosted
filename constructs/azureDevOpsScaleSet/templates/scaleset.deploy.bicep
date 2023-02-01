targetScope = 'subscription'

// ================ //
// Input Parameters //
// ================ //

// Resource Group Parameters
@description('Optional. The name of the Resource Group.')
param resourceGroupName string = 'agents-vmss-rg'

// Network Security Group Parameters
@description('Optional. The name of the Network Security Group.')
param networkSecurityGroupName string = 'vmss-nsg'

// Virtual Network Parameters
@description('Optional. The name of the Virtual Network.')
param virtualNetworkName string = 'vmss-vnet'

@description('Optional. The address space of the Virtual Network.')
param virtualNetworkAddressPrefix string = '10.0.0.0/16'

@description('Optional. The name of the Virtual Network Subnet.')
param virutalNetworkSubnetName string = 'vmsssubnet'

@description('Optional. The address space of the Virtual Network Subnet.')
param virutalNetworkSubnetAddressPrefix string = '10.0.0.0/24'

// Virtual Machine Scale Set Parameters
@description('Optional. The name of the Virtual Machine Scale Set.')
param virtualMachineScaleSetName string = 'agent-scaleset'

@description('Optional. The Virtual Machine name prefix of the Virtual Machine Scale Set.')
param virtualMachineScaleSetVMNamePrefix string = 'vmssvm'

@description('Required. The OS type of the Virtual Machine Scale Set.')
param virtualMachineScaleSetOsType string

@description('Optional. The SKU Size of the Virtual Machine Scale Set.')
param virtualMachineScaleSetSKUSize string = 'Standard_B2s'

@description('Required. Disable/Enable password authentication of the Virtual Machine Scale Set.')
param virtualMachineScaleSetDisablePasswordAuthentication bool

@description('Optional. The Public Keys of the Virtual Machine Scale Set.')
param virtualMachineScaleSetPublicKeys array = []

@description('Optional. The admin password of the Virtual Machine Scale Set.')
@secure()
param virtualMachineScaleSetAdminPassword string = ''

@description('Optional. The admin user name of the Virtual Machine Scale Set.')
param virtualMachineScaleSetAdminUserName string = 'scaleSetAdmin'

@description('Required. The name of the Azure Compute Gallery that hosts the image of the Virtual Machine Scale Set.')
param virtualMachineScaleSetComputeGalleryName string

@description('Required. The name of Image Definition of the Azure Compute Gallery that hosts the image of the Virtual Machine Scale Set.')
param virtualMachineScaleSetComputeGalleryImageDefinitionName string

@description('Optional. The version of the image to use in the Virtual Machine Scale Set.')
param virtualMachineScaleSetImageVersion string = 'latest'

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
module rg '../../../CARML0.9/Microsoft.Resources/resourceGroups/deploy.bicep' = if (deploymentsToPerform == 'All') {
  name: '${deployment().name}-rg'
  params: {
    name: resourceGroupName
    location: location
  }
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

// Virtual Network
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
        name: virutalNetworkSubnetName
        addressPrefix: virutalNetworkSubnetAddressPrefix
        networkSecurityGroupId: nsg.outputs.resourceId
      }
    ]
    location: location
  }
  dependsOn: [
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
module vmss '../../../CARML0.9/Microsoft.Compute/virtualMachineScaleSets/deploy.bicep' = {
  name: '${deployment().name}-vmss'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: virtualMachineScaleSetName
    vmNamePrefix: virtualMachineScaleSetVMNamePrefix
    skuName: virtualMachineScaleSetSKUSize
    skuCapacity: 0
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
