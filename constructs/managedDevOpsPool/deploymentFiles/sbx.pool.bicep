targetScope = 'subscription'

//////////////////////////
//   Input Parameters   //
//////////////////////////

@description('Optional. Specifies the location for resources.')
param resourceLocation string = 'NorthEurope'

/////////////////////////////
//   Template Deployment   //
/////////////////////////////
module managedDevOpsPoolDeployment '../templates/pool.deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-managedPool-sbx'
  params: {
    resourceLocation: resourceLocation
    computeGalleryName: '<computeGalleryName>'
    computeGalleryImageDefinitionName: 'sid-linux'
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
