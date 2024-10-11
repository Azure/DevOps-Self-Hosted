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
    poolMaximumConcurrency: 5
    poolManagedIdentities: {
      userAssignedResourceIds: [
        '/subscriptions/b765c5e5-ae60-4724-9b59-36fbcf56795b/resourceGroups/rg-ado-agents/providers/Microsoft.ManagedIdentity/userAssignedIdentities/msi-ds'
        '/subscriptions/b765c5e5-ae60-4724-9b59-36fbcf56795b/resourceGroups/rg-ado-agents/providers/Microsoft.ManagedIdentity/userAssignedIdentities/msi-aib'
      ]
    }
    devOpsInfrastructureEnterpriseApplicationObjectId: 'a67e26cd-08dc-47be-8217-df02edb89ba8' // Tenant-specific 'DevOpsInfrastructure' Enterprise Application objectId
  }
}
