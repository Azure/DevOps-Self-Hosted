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

/////////////////////////////
//   Template Deployment   //
/////////////////////////////
var computeGalleryImageDefinitionName = 'sid-windows'
var assetsStorageAccountName = 'alsehrst'
var assetsStorageAccountContainerName = 'aibscripts'
var installPwshScriptName = 'Install-WindowsPowerShell.ps1'
var initializeSoftwareScriptName = 'Initialize-WindowsSoftware.ps1'

module imageDeployment '../templates/image.deploy.bicep' = {
  name: '${uniqueString(deployment().name, resourceLocation)}-image-sbx'
  params: {
    resourceLocation: resourceLocation
    deploymentsToPerform: deploymentsToPerform
    computeGalleryName: 'alsehrcg'
    computeGalleryImageDefinitionName: computeGalleryImageDefinitionName
    waitForImageBuild: waitForImageBuild

    assetsStorageAccountName: assetsStorageAccountName
    assetsStorageAccountContainerName: assetsStorageAccountContainerName

    computeGalleryImageDefinitions: [
      {
        name: computeGalleryImageDefinitionName
        osType: 'Windows'
        identifier: {
          publisher: 'devops'
          offer: 'devops_windows'
          sku: 'devops_windows_az'
        }
        osState: 'Generalized'
        hyperVGeneration: 'V2'
      }
    ]
    storageAccountFilesToUpload: [
      {
        name: installPwshScriptName
        value: loadTextContent('../scripts/uploads/windows/${installPwshScriptName}')
      }
      {
        name: initializeSoftwareScriptName
        value: loadTextContent('../scripts/uploads/windows/${initializeSoftwareScriptName}')
      }
    ]
    imageTemplateImageSource: {
      type: 'PlatformImage'
      publisher: 'MicrosoftWindowsDesktop'
      offer: 'Windows-11'
      sku: 'win11-24h2-avd'
      version: 'latest'
    }

    imageTemplateResourceGroupName: ''
    imageTemplateCustomizationSteps: [
      {
        type: 'PowerShell'
        name: 'PowerShell Core installation'
        scriptUri: 'https://${assetsStorageAccountName}.blob.${environment().suffixes.storage}/${assetsStorageAccountContainerName}/${installPwshScriptName}'
      }
      {
        type: 'File'
        name: 'Download ${initializeSoftwareScriptName}'
        sourceUri: 'https://${assetsStorageAccountName}.blob.${environment().suffixes.storage}/${assetsStorageAccountContainerName}/${initializeSoftwareScriptName}'
        destination: initializeSoftwareScriptName
      }
      {
        type: 'PowerShell'
        name: 'Software installation'
        inline: [
          'pwsh \'${initializeSoftwareScriptName}\''
        ]
      }
    ]
  }
}