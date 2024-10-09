@description('Required. ')
param location string

@description('Required. Defines how many resources can there be created at any given time.')
@minValue(1)
@maxValue(10000)
param maximumConcurrency int

@description('Required. The name of the subnet the agents should be deployed into.')
param subnetName string

@description('Required. The resource Id of the Virtual Network the agents should be deployed into.')
param virtualNetworkResourceId string

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

@description('Required. The name of the Azure Compute Gallery that hosts the image of the Virtual Machine Scale Set.')
param virtualMachineScaleSetComputeGalleryName string

@description('Required. The name of Image Definition of the Azure Compute Gallery that hosts the image of the Virtual Machine Scale Set.')
param virtualMachineScaleSetComputeGalleryImageDefinitionName string

@description('Optional. The version of the image to use in the Virtual Machine Scale Set.')
param virtualMachineScaleSetImageVersion string = 'latest' // Note, 'latest' is not supported by resource type

resource computeGallery 'Microsoft.Compute/galleries@2022-03-03' existing = {
  name: virtualMachineScaleSetComputeGalleryName

  resource imageDefinition 'images@2022-03-03' existing = {
    name: virtualMachineScaleSetComputeGalleryImageDefinitionName

    resource imageVersion 'versions@2022-03-03' existing = {
      name: virtualMachineScaleSetImageVersion
    }
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: last(split(virtualNetworkResourceId, '/'))

  resource subnet 'subnets@2024-01-01' existing = {
    name: subnetName
  }
}

resource imageVersionPermission 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    computeGallery::imageDefinition.id,
    devOpsInfrastructureEnterpriseApplicationObjectId,
    subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
  )
  properties: {
    principalId: devOpsInfrastructureEnterpriseApplicationObjectId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'acdd72a7-3385-48ef-bd42-f606fba81ae7'
    ) // Reader
    principalType: 'ServicePrincipal'
  }
  scope: computeGallery::imageDefinition // ::imageVersion Not using imageVersion as scope to enable to principal to find 'latest'. A role assignment on 'latest' is not possible
}

resource vnetPermissions 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    vnet.id,
    devOpsInfrastructureEnterpriseApplicationObjectId,
    subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')
  )
  properties: {
    principalId: devOpsInfrastructureEnterpriseApplicationObjectId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4d97b98b-1d4f-4787-a291-c67834d212e7'
    ) // Network Contributor
    principalType: 'ServicePrincipal'
  }
  scope: vnet
}

resource devCenter 'Microsoft.DevCenter/devcenters@2024-02-01' = {
  name: devCenterName
  location: location
}

resource devCenterProject 'Microsoft.DevCenter/projects@2024-02-01' = {
  name: devCenterProjectName
  location: location
  properties: {
    devCenterId: devCenter.id
  }
}

// Requires: https://github.com/Azure/bicep-registry-modules/pull/3401
// module pool 'br/public:avm/res/dev-ops-infrastructure/pool:0.1.0' = {
//   name:
//   params: {
//     name: poolName
//     agentProfile: agentProfile
//     concurrency: maximumConcurrency
//     devCenterProjectResourceId: devCenterProject.id
//     fabricProfileSkuName: devOpsInfrastructurePoolSize
//     images:  [
//       {
//          resourceId: computeGallery::imageDefinition::imageVersion.id
//       }
//     ]
//     organizationProfile: {
//       kind: 'AzureDevOps'
//       organizations: [
//         {
//           url: 'https://dev.azure.com/${organizationName}'
//           projects: projectNames
//         }
//       ]
//     }
//   }
// }

resource name 'Microsoft.DevOpsInfrastructure/pools@2024-04-04-preview' = {
  name: poolName
  location: location
  properties: {
    maximumConcurrency: maximumConcurrency
    agentProfile: {
      kind: 'Stateless'
    }
    organizationProfile: {
      kind: 'AzureDevOps'
      organizations: [
        {
          url: 'https://dev.azure.com/${organizationName}'
          projects: projectNames
        }
      ]
    }
    devCenterProjectResourceId: devCenterProject.id
    fabricProfile: {
      sku: {
        name: devOpsInfrastructurePoolSize
      }
      kind: 'Vmss'
      images: [
        {
          resourceId: computeGallery::imageDefinition::imageVersion.id
        }
      ]
      networkProfile: {
        subnetId: vnet::subnet.id
      }
    }
  }
  dependsOn: [
    imageVersionPermission
    vnetPermissions
  ]
}
