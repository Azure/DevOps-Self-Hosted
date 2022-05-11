targetScope = 'subscription'

// ================ //
// Input Parameters //
// ================ //

@description('Required. The resource group properties')
param rgParam object

@description('Required. The network security group properties')
param nsgParam object

@description('Required. The virtual network properties')
param vnetParam object

@description('Required. The virtual machine scale set properties')
param vmssParam object

@description('Optional. The admin password to use if the scale set uses a windows image')
@secure()
param vmssAdminPassword string = ''

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
module rg '../../../CARML0.5/Microsoft.Resources/resourceGroups/deploy.bicep' = if (deploymentsToPerform == 'All') {
  name: '${deployment().name}-rg'
  params: {
    name: rgParam.name
    location: location
  }
}

// Network Security Group
module nsg '../../../CARML0.5/Microsoft.Network/networkSecurityGroups/deploy.bicep' = if (deploymentsToPerform == 'All') {
  name: '${deployment().name}-nsg'
  scope: resourceGroup(rgParam.name)
  params: {
    name: nsgParam.name
    location: location
  }
  dependsOn: [
    rg
  ]
}

// Virtual Network
module vnet '../../../CARML0.5/Microsoft.Network/virtualNetworks/deploy.bicep' = if (deploymentsToPerform == 'All') {
  name: '${deployment().name}-vnet'
  scope: resourceGroup(rgParam.name)
  params: {
    name: vnetParam.name
    addressPrefixes: vnetParam.addressPrefixes
    subnets: vnetParam.subnets
    location: location
  }
  dependsOn: [
    nsg
    rg
  ]
}

// Virtual Machine Scale Set
module vmss '../../../CARML0.5/Microsoft.Compute/virtualMachineScaleSets/deploy.bicep' = {
  name: '${deployment().name}-vmss'
  scope: resourceGroup(rgParam.name)
  params: {
    name: vmssParam.name
    vmNamePrefix: vmssParam.vmNamePrefix
    skuName: contains(vmssParam, 'skuName') ? vmssParam.skuName : 'Standard_B2s'
    skuCapacity: contains(vmssParam, 'skuCapacity') ? vmssParam.skuCapacity : 1
    upgradePolicyMode: contains(vmssParam, 'upgradePolicyMode') ? vmssParam.upgradePolicyMode : 'Manual'
    vmPriority: contains(vmssParam, 'vmPriority') ? vmssParam.vmPriority : 'Regular'
    osDisk: contains(vmssParam, 'osDisk') ? vmssParam.osDisk : {
      createOption: 'fromImage'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    systemAssignedIdentity: contains(vmssParam, 'systemAssignedIdentity') ? vmssParam.systemAssignedIdentity : true
    osType: vmssParam.osType
    imageReference: vmssParam.imageReference
    adminUsername: contains(vmssParam, 'adminUsername') ? vmssParam.adminUsername : 'scaleSetAdmin'
    disablePasswordAuthentication: vmssParam.disablePasswordAuthentication
    nicConfigurations: vmssParam.nicConfigurations
    scaleInPolicy: contains(vmssParam, 'scaleInPolicy') ? vmssParam.scaleInPolicy : {
      rules: [
        'Default'
      ]
    }
    adminPassword: !empty(vmssAdminPassword) ? vmssAdminPassword : ''
    publicKeys: contains(vmssParam, 'publicKeys') ? vmssParam.publicKeys : ''
    location: location
  }
  dependsOn: [
    vnet
  ]
}
