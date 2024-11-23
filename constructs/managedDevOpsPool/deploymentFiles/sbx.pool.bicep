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
  name: '${uniqueString(deployment().name, resourceLocation)}-managedPool-sbx'
  params: {
    resourceLocation: resourceLocation
    computeGalleryName: 'alsehrcg'
    computeGalleryImageDefinitionName: 'sid-linux'
    devCenterName: 'my-center'
    devCenterProjectName: 'my-project'
    organizationName: 'asehr'
    projectNames: ['Onyx']
    poolName: 'onyx-pool'
    poolMaximumConcurrency: 5
    // Tenant-specific 'DevOpsInfrastructure' Enterprise Application objectId.
    // Can be fetched by running `(Get-AzAdServicePrincipal -DisplayName 'DevOpsInfrastructure').Id` while logged into the tenant to deploy into.
    devOpsInfrastructureEnterpriseApplicationObjectId: 'a67e26cd-08dc-47be-8217-df02edb89ba8'
  }
}
