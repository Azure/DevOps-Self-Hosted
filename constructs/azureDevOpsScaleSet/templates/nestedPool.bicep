param computeImageResourceId string
param devCenterName string
param devCenterProjectName string
param location string
param poolName string
param organizationName string
param projectNames string[]?
param maximumConcurrency int
param subnetResourceId string

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
          resourceId: computeImageResourceId
        }
      ]
      networkProfile: {
        subnetId: subnetResourceId
      }
    }
  }
}
