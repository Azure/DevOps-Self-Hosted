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
    addressPrefix: cidrSubnet('10.0.0.0', 24, 0) // 10.0.0.0 - 10.0.0.255
    delegation: 'Microsoft.DevOpsInfrastructure/pools'
  }
]

@description('Required. The name of the Azure Compute Gallery that hosts the image of the Managed DevOps Pool.')
param computeGalleryName string

@description('Required. The name of Image Definition of the Azure Compute Gallery that hosts the image of the Managed DevOps Pool.')
param computeGalleryImageDefinitionName string

@description('Optional. The version of the image to use in the Managed DevOps Pool.')
param imageVersion string = 'latest'

@description('Required. The name of the Azure DevOps agent pool to create.')
param poolName string

@description('Required. The name of the Azure DevOps organization to register the agent pools in.')
param organizationName string

@description('Optional. The Azure DevOps projects to register the agent pools in. In none is provided, the pool is only registered in the organization.')
param projectNames string[]?

@description('Required. The name of the Dev Center to use for the DevOps Infrastructure Pool. Must be lower case and may contain hyphens.')
@minLength(3)
@maxLength(26)
param devCenterName string

@description('Required. The name of the Dev Center project to use for the DevOps Infrastructure Pool.')
@minLength(3)
@maxLength(63)
param devCenterProjectName string

@description('Optional. The Azure SKU name of the machines in the pool.')
param devOpsInfrastructurePoolSize string = 'Standard_B1ms'

@description('Required. The object ID (principal id) of the \'DevOpsInfrastructure\' Enterprise Application in your tenant.')
param devOpsInfrastructureEnterpriseApplicationObjectId string

// Shared Parameters
@description('Optional. The location to deploy into')
param resourceLocation string = deployment().location

// =========== //
// Deployments //
// =========== //

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: resourceLocation
}

// Network Security Group
module nsg 'br/public:avm/res/network/network-security-group:0.3.0' = {
  name: '${deployment().name}-nsg'
  scope: rg
  params: {
    name: networkSecurityGroupName
    location: resourceLocation
  }
}

// Virtual Network
module vnet 'br/public:avm/res/network/virtual-network:0.4.0' = {
  name: '${deployment().name}-vnet'
  scope: rg
  params: {
    name: virtualNetworkName
    addressPrefixes: [
      virtualNetworkAddressPrefix
    ]
    subnets: virtualNetworkSubnets
    location: resourceLocation
  }
}

module pool 'nestedPool.bicep' = {
  scope: rg
  name: '${deployment().name}-pool'
  params: {
    location: resourceLocation
    devCenterName: devCenterName
    devCenterProjectName: devCenterProjectName
    maximumConcurrency: 1
    poolName: poolName
    organizationName: organizationName
    projectNames: projectNames
    virtualNetworkResourceId: vnet.outputs.resourceId
    devOpsInfrastructurePoolSize: devOpsInfrastructurePoolSize
    subnetName: vnet.outputs.subnetNames[0]
    computeGalleryImageDefinitionName: computeGalleryImageDefinitionName
    computeGalleryName: computeGalleryName
    imageVersion: imageVersion
    devOpsInfrastructureEnterpriseApplicationObjectId: devOpsInfrastructureEnterpriseApplicationObjectId
  }
}
