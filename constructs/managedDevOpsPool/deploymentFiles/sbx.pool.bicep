targetScope = 'subscription'

//////////////////////////
//   Input Parameters   //
//////////////////////////

@description('Optional. Specifies the location for resources.')
param resourceLocation string = 'NorthEurope'

///////////////////////////////
//   Deployment Properties   //
///////////////////////////////

resource computeGallery 'Microsoft.Compute/galleries@2022-03-03' existing = {
  name: '<computeGalleryName>'
  scope: resourceGroup('rg-ado-agents')

  resource imageDefinition 'images@2022-03-03' existing = {
    name: 'sid-linux'
  }
}

/////////////////////////////
//   Template Deployment   //
/////////////////////////////
module managedDevOpsPoolDeployment '../templates/pool.deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-managedPool-sbx'
  params: {
    resourceLocation: resourceLocation
    computeGalleryImageDefinitionResourceId: computeGallery::imageDefinition.id
    devCenterName: 'my-center'
    devCenterProjectName: 'my-project'
    organizationName: '<YourOrganization>'
    projectNames: ['<YourProject>']
    poolName: '<YourAgentPoolName>'
    poolMaximumConcurrency: 5
    // Tenant-specific 'DevOpsInfrastructure' Enterprise Application objectId.
    // Can be fetched by running `(Get-AzAdServicePrincipal -DisplayName 'DevOpsInfrastructure').Id` while logged into the tenant to deploy into.
    devOpsInfrastructureEnterpriseApplicationObjectId: '<YourEAObjectId>'
  }
}
