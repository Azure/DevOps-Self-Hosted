targetScope = 'subscription'

//////////////////////////
//   Input Parameters   //
//////////////////////////
@description('Optional. A parameter to control which deployments should be executed')
@allowed([
  'All'
  'Only Scale Set'
])
param deploymentsToPerform string = 'All'

@description('Optional. Specifies the location for resources.')
param location string = 'WestEurope'

///////////////////////////////
//   Deployment Properties   //
///////////////////////////////

// Resource Group
var rgParam = {
  name: 'agents-vmss-rg'
}

// Network Security Group
var nsgParam = {
  name: 'vmss-nsg'
}

// Virtual Network
var vnetParam = {
  name: 'vmss-vnet'
  addressPrefixes: [
    '10.0.0.0/16'
  ]
  subnets: [
    {
      name: 'vmsssubnet'
      addressPrefix: '10.0.0.0/24'
      networkSecurityGroupName: 'vmss-nsg'
    }
  ]
}

// Virtual Machine Scale Set
var vmssParam = {
  name: 'agent-scaleset'
  vmNamePrefix: 'vmssvm'
  // osType: 'Linux'
  skuCapacity: 0
  // imageReference: {
  //   id: '${subscription().id}/resourceGroups/${rgParam.name}/providers/Microsoft.Compute/galleries/aibgallery/images/linux-sid/versions/latest'
  // }
  // disablePasswordAuthentication: true
  // publicKeys: [
  //   {
  //     path: '/home/scaleSetAdmin/.ssh/authorized_keys'
  //     keyData: 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDdOir5eO28EBwxU0Dyra7g9h0HUXDyMNFp2z8PhaTUQgHjrimkMxjYRwEOG/lxnYL7+TqZk+HcPTfbZOunHBw0Wx2CITzILt6531vmIYZGfq5YyYXbxZa5MON7L/PVivoRlPj5Z/t4RhqMhyfR7EPcZ516LJ8lXPTo8dE/bkOCS+kFBEYHvPEEKAyLs19sRcK37SeHjpX04zdg62nqtuRr00Tp7oeiTXA1xn5K5mxeAswotmd8CU0lWUcJuPBWQedo649b+L2cm52kTncOBI6YChAeyEc1PDF0Tn9FmpdOWKtI9efh+S3f8qkcVEtSTXoTeroBd31nzjAunMrZeM8Ut6dre+XeQQIjT7I8oEm+ZkIuIyq0x2fls8JXP2YJDWDqu8v1+yLGTQ3Z9XVt2lMti/7bIgYxS0JvwOr5n5L4IzKvhb4fm13LLDGFa3o7Nsfe3fPb882APE0bLFCmfyIeiPh7go70WqZHakpgIr6LCWTyePez9CsI/rfWDb6eAM8= generated-by-azure'
  //   }
  // ]
  nicConfigurations: [
    {
      nicSuffix: '-nic01'
      enableAcceleratedNetworking: false
      ipConfigurations: [
        {
          name: 'ipconfig1'
          properties: {
            subnet: {
              id: '${subscription().id}/resourceGroups/${rgParam.name}/providers/Microsoft.Network/virtualNetworks/${vnetParam.name}/subnets/${vnetParam.subnets[0].name}'
            }
          }
        }
      ]
    }
  ]
  // Windows example
  osType: 'Windows'
  imageReference: {
    id: '${subscription().id}/resourceGroups/${rgParam.name}/providers/Microsoft.Compute/galleries/aibgallery/images/windows-sid/versions/latest'
  }
  disablePasswordAuthentication: false
  //adminPassword: kv.getSecret('adminPassword')
  adminPassword: guid(subscription().id)
}
// // For the Windows example
// resource kv 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
//   name: 'agent-vmss-core'
//   scope: resourceGroup(subscription().subscriptionId, 'agents-vmss-rg')
// }

/////////////////////////////
//   Template Deployment   //
/////////////////////////////
module scaleSetDeployment '../templates/scaleset.deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-scaleSet-sbx'
  params: {
    location: location
    rgParam: rgParam
    nsgParam: nsgParam
    vnetParam: vnetParam
    vmssParam: vmssParam
    deploymentsToPerform: deploymentsToPerform
  }
}
