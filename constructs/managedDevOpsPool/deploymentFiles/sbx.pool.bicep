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
    poolManagedIdentities: {
      userAssignedResourceIds: [
        '/subscriptions/b765c5e5-ae60-4724-9b59-36fbcf56795b/resourceGroups/core-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/temp-test-uai'
      ]
    }
    computeGalleryResourceGroupName: 'core-rg'
    computeGalleryName: 'coregallery' // '<computeGalleryName>'
    computeGalleryImageDefinitionName: 'core-linux-sid' // 'sid-linux'
    devCenterName: 'my-center'
    devCenterProjectName: 'my-project'
    organizationName: 'asehr' // '<YourOrganization>'
    projectNames: ['Onyx'] // ['<YourProject>']
    poolName: 'onyx-pool' // '<YourAgentPoolName>'
    poolMaximumConcurrency: 5
    // Tenant-specific 'DevOpsInfrastructure' Enterprise Application objectId.
    // Can be fetched by running `(Get-AzAdServicePrincipal -DisplayName 'DevOpsInfrastructure').Id` while logged into the tenant to deploy into.
    devOpsInfrastructureEnterpriseApplicationObjectId: 'a67e26cd-08dc-47be-8217-df02edb89ba8' // '<YourEAObjectId>'
  }
}
