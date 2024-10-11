targetScope = 'subscription'

//////////////////////////
//   Input Parameters   //
//////////////////////////

@description('Optional. Specifies the location for resources.')
param resourceLocation string = 'NorthEurope'

///////////////////////////////
//   Deployment Properties   //
///////////////////////////////

/////////////////////////////
//   Template Deployment   //
/////////////////////////////
module managedDevOpsPoolDeployment '../templates/pool.deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-scaleSet-sbx'
  params: {
    resourceLocation: resourceLocation
    computeGalleryName: 'galaib'
    computeGalleryImageDefinitionName: 'sid-linux'
    devCenterName: 'my-center'
    devCenterProjectName: 'my-project'
    organizationName: 'asehr'
    projectNames: ['Onyx']
    poolName: 'onyx-pool'
    poolMaximumConcurrency: 10
    devOpsInfrastructureEnterpriseApplicationObjectId: 'a67e26cd-08dc-47be-8217-df02edb89ba8' // Tenant-specific 'DevOpsInfrastructure' Enterprise Application objectId
  }
}
