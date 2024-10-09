targetScope = 'subscription'

//////////////////////////
//   Input Parameters   //
//////////////////////////
@description('Optional. A parameter to control which deployments should be executed')
@allowed([
  'All'
  'Only Scale Set'
])
param deploymentsToPerform string = 'All'

@description('Optional. Specifies the location for resources.')
param resourceLocation string = 'NorthEurope'

///////////////////////////////
//   Deployment Properties   //
///////////////////////////////

/////////////////////////////
//   Template Deployment   //
/////////////////////////////
module scaleSetDeployment '../templates/pool.deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-scaleSet-sbx'
  params: {
    resourceLocation: resourceLocation
    deploymentsToPerform: deploymentsToPerform
    virtualMachineScaleSetComputeGalleryName: 'galaib'

    // TODO: Clean up
    // Linux example
    // virtualMachineScaleSetOsType: 'Linux'
    // virtualMachineScaleSetDisablePasswordAuthentication: true
    // virtualMachineScaleSetPublicKeys: [
    //   {
    //     path: '/home/scaleSetAdmin/.ssh/authorized_keys'
    //     keyData: 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDdOir5eO28EBwxU0Dyra7g9h0HUXDyMNFp2z8PhaTUQgHjrimkMxjYRwEOG/lxnYL7+TqZk+HcPTfbZOunHBw0Wx2CITzILt6531vmIYZGfq5YyYXbxZa5MON7L/PVivoRlPj5Z/t4RhqMhyfR7EPcZ516LJ8lXPTo8dE/bkOCS+kFBEYHvPEEKAyLs19sRcK37SeHjpX04zdg62nqtuRr00Tp7oeiTXA1xn5K5mxeAswotmd8CU0lWUcJuPBWQedo649b+L2cm52kTncOBI6YChAeyEc1PDF0Tn9FmpdOWKtI9efh+S3f8qkcVEtSTXoTeroBd31nzjAunMrZeM8Ut6dre+XeQQIjT7I8oEm+ZkIuIyq0x2fls8JXP2YJDWDqu8v1+yLGTQ3Z9XVt2lMti/7bIgYxS0JvwOr5n5L4IzKvhb4fm13LLDGFa3o7Nsfe3fPb882APE0bLFCmfyIeiPh7go70WqZHakpgIr6LCWTyePez9CsI/rfWDb6eAM8= generated-by-azure'
    //   }
    // ]
    virtualMachineScaleSetComputeGalleryImageDefinitionName: 'sid-linux'

    devCenterName: 'my-center'
    devCenterProjectName: 'my-project'
    organizationName: 'asehr'
    projectNames: ['Onyx']
    poolName: 'onyx-pool'
    devOpsInfrastructureEnterpriseApplicationObjectId: 'a67e26cd-08dc-47be-8217-df02edb89ba8' // Tenant-specific 'DevOpsInfrastructure' Enterprise Application objectId

    // Windows example
    // virtualMachineScaleSetOsType: 'Windows'
    // virtualMachineScaleSetComputeGalleryImageDefinitionName: 'sid-windows'
    // virtualMachineScaleSetDisablePasswordAuthentication: false
    // virtualMachineScaleSetAdminPassword: kv.getSecret('adminPassword')
  }
}
