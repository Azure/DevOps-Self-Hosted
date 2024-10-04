// param computeImageResourceId string
param devCenterName string
param devCenterProjectName string
param location string
param poolName string
param organizationName string
param projectNames string[]?
param maximumConcurrency int
param subnetResourceId string
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

resource permission 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
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
        name: 'Standard_B1ms'
      }
      kind: 'Vmss'
      images: [
        {
          resourceId: computeGallery::imageDefinition::imageVersion.id
        }
      ]
      networkProfile: {
        subnetId: subnetResourceId
      }
    }
  }
  dependsOn: [
    permission
  ]
}
