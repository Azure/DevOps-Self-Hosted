targetScope = 'subscription'

// ================ //
// Input Parameters //
// ================ //

// Resource Group Parameters
@description('Optional. The name of the Resource Group.')
param resourceGroupName string = 'rg-ado-agents'

// Network Security Group Parameters
@description('Optional. The name of the Network Security Group.')
param networkSecurityGroupName string = 'nsg-pool'

// Virtual Network Parameters
@description('Optional. The name of the Virtual Network.')
param virtualNetworkName string = 'vnet-pool'

@description('Optional. The address space of the Virtual Network.')
param virtualNetworkAddressPrefix string = '10.0.0.0/16'

@description('Optional. The subnets to create in the Virtual Network.')
param virtualNetworkSubnets array = [
  {
    name: 'poolsubnet'
    addressPrefix: cidrSubnet('10.0.0.0', 24, 0) // 10.0.0.0 - 10.0.0.255
    delegation: 'Microsoft.DevOpsInfrastructure/pools'
  }
]

@description('Required. The name of the Resource Group containing the Azure Compute Gallery that hosts the image of the Managed DevOps Pool.')
param computeGalleryResourceGroupName string = resourceGroupName

@description('Required. The name of the Azure Compute Gallery that hosts the image of the Managed DevOps Pool.')
param computeGalleryName string

@description('Required. The name of Image Definition of the Azure Compute Gallery that hosts the image of the Managed DevOps Pool.')
param computeGalleryImageDefinitionName string

@description('Optional. The version of the image to use in the Managed DevOps Pool.')
param imageVersion string = 'latest'

@description('Required. The name of the Azure DevOps agent pool to create.')
param poolName string

@description('Optional. Defines how many agents can there be deployed at any given time.')
@minValue(1)
@maxValue(10000)
param poolMaximumConcurrency int = 1

@description('Optional. The Azure SKU name of the machines in the pool.')
param poolSize string = 'Standard_B1ms'

@description('Optional. The managed identity definition for the Managed DevOps Pool.')
import { managedIdentityOnlyUserAssignedType } from 'br/public:avm/utl/types/avm-common-types:0.3.0'
param poolManagedIdentities managedIdentityOnlyUserAssignedType?

@description('Optional. Defines how the machine will be handled once it executed a job.')
import { agentProfileType } from 'br/public:avm/res/dev-ops-infrastructure/pool:0.2.0'
param poolAgentProfile agentProfileType = {
  kind: 'Stateless'
}

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
  name: '${uniqueString(deployment().name, resourceLocation)}-nsg'
  scope: rg
  params: {
    name: networkSecurityGroupName
    location: resourceLocation
  }
}

// Virtual Network
module vnet 'br/public:avm/res/network/virtual-network:0.4.0' = {
  name: '${uniqueString(deployment().name, resourceLocation)}-vnet'
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

module devCenter 'devCenter.bicep' = {
  scope: rg
  name: '${uniqueString(deployment().name, resourceLocation)}-devCenter'
  params: {
    location: resourceLocation
    devCenterName: devCenterName
    devCenterProjectName: devCenterProjectName
  }
}

resource computeGallery 'Microsoft.Compute/galleries@2022-03-03' existing = {
  name: computeGalleryName
  scope: resourceGroup(computeGalleryResourceGroupName)

  resource imageDefinition 'images@2022-03-03' existing = {
    name: computeGalleryImageDefinitionName

    resource version 'versions@2022-03-03' existing = {
      name: imageVersion
    }
  }
}

module imagePermission 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.1' = {
  scope: resourceGroup(computeGalleryResourceGroupName)
  name: '${uniqueString(deployment().name, resourceLocation)}-devOpsInfrastructureEAObjectId-permission-image'
  params: {
    principalId: devOpsInfrastructureEnterpriseApplicationObjectId
    resourceId: computeGallery::imageDefinition.id
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'acdd72a7-3385-48ef-bd42-f606fba81ae7'
    ) // Reader
  }
}
module vnetPermission 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.1' = {
  scope: rg
  name: '${uniqueString(deployment().name, resourceLocation)}-devOpsInfrastructureEAObjectId-permission-vnet'
  params: {
    principalId: devOpsInfrastructureEnterpriseApplicationObjectId
    resourceId: vnet.outputs.resourceId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4d97b98b-1d4f-4787-a291-c67834d212e7'
    ) // Network Contributor
  }
}

module pool 'br/public:avm/res/dev-ops-infrastructure/pool:0.2.0' = {
  name: '${uniqueString(deployment().name, resourceLocation)}-pool'
  scope: rg
  params: {
    name: poolName
    managedIdentities: poolManagedIdentities
    agentProfile: poolAgentProfile
    concurrency: poolMaximumConcurrency
    devCenterProjectResourceId: devCenter.outputs.devCenterProjectResourceId
    fabricProfileSkuName: poolSize
    images: [
      {
        resourceId: computeGallery::imageDefinition::version.id
      }
    ]
    organizationProfile: {
      kind: 'AzureDevOps'
      organizations: [
        {
          url: 'https://dev.azure.com/${organizationName}'
          projects: projectNames
        }
      ]
    }
    subnetResourceId: vnet.outputs.subnetResourceIds[0]
  }
  dependsOn: [
    imagePermission
    vnetPermission
  ]
}
