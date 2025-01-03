targetScope = 'subscription'

//////////////////////////
//   Input Parameters   //
//////////////////////////
@description('Optional. A parameter to control which deployments should be executed')
@allowed([
  'All'
  'Only base'
  'Only assets & image'
  'Only image'
])
param deploymentsToPerform string = 'All'

@description('Optional. Specifies the location for resources.')
param resourceLocation string = 'NorthEurope'

@description('Optional. A parameter to control if the deployment should wait for the image build to complete.')
param waitForImageBuild bool = true

///////////////////////////////////////////////
//   Multi-referenced deployment variables   //
///////////////////////////////////////////////
var computeGalleryImageDefinitionName = 'sid-linux'
var assetsStorageAccountName = '<assetsStorageAccountName>'
var assetsStorageAccountContainerName = 'aibscripts'
var installPwshScriptName = 'Install-LinuxPowerShell.sh'
var initializeSoftwareScriptName = 'Initialize-LinuxSoftware.ps1'

/////////////////////////////
//   Template deployment   //
/////////////////////////////
module imageDeployment '../templates/image.deploy.bicep' = {
  name: '${uniqueString(deployment().name, resourceLocation)}-image-sbx'
  params: {
    resourceLocation: resourceLocation
    deploymentsToPerform: deploymentsToPerform
    computeGalleryName: '<computeGalleryName>'
    computeGalleryImageDefinitionName: computeGalleryImageDefinitionName
    waitForImageBuild: waitForImageBuild
    computeGalleryImageDefinitions: [
      {
        name: computeGalleryImageDefinitionName
        osType: 'Linux'
        identifier: {
          publisher: 'devops'
          offer: 'devops_linux'
          sku: 'devops_linux_az'
        }
        osState: 'Generalized'
        hyperVGeneration: 'V2'
      }
    ]

    assetsStorageAccountName: assetsStorageAccountName
    assetsStorageAccountContainerName: assetsStorageAccountContainerName

    storageAccountFilesToUpload: [
      {
        name: installPwshScriptName
        value: loadTextContent('../scripts/uploads/linux/${installPwshScriptName}')
      }
      {
        name: initializeSoftwareScriptName
        value: loadTextContent('../scripts/uploads/linux/${initializeSoftwareScriptName}')
      }
    ]
    imageTemplateImageSource: {
      type: 'PlatformImage'
      publisher: 'canonical'
      offer: '0001-com-ubuntu-server-jammy'
      sku: '22_04-lts-gen2'
      version: 'latest'
      // Custom image example
      // type: 'SharedImageVersion'
      // imageVersionID: '${subscription().id}/resourceGroups/myRg/providers/Microsoft.Compute/galleries/<computeGalleryName>/images/${computeGalleryImageDefinitionName}/versions/0.24470.675'
    }
    imageTemplateCustomizationSteps: [
      {
        type: 'Shell'
        name: 'PowerShell installation'
        scriptUri: 'https://${assetsStorageAccountName}.blob.${az.environment().suffixes.storage}/${assetsStorageAccountContainerName}/${installPwshScriptName}'
      }
      {
        type: 'File'
        name: 'Download ${initializeSoftwareScriptName}'
        sourceUri: 'https://${assetsStorageAccountName}.blob.${az.environment().suffixes.storage}/${assetsStorageAccountContainerName}/${initializeSoftwareScriptName}'
        destination: initializeSoftwareScriptName
      }
      {
        type: 'Shell'
        name: 'Software installation'
        inline: [
          'pwsh \'${initializeSoftwareScriptName}\''
        ]
      }
    ]
  }
}
