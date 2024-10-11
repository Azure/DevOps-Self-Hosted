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

module imageDeployment '../templates/image.deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-image-sbx'
  params: {
    resourceLocation: resourceLocation
    deploymentsToPerform: deploymentsToPerform
    computeGalleryName: '<computeGalleryName>'
    computeGalleryImageDefinitionName: 'sid-linux'
    waitForImageBuild: waitForImageBuild
    computeGalleryImageDefinitions: [
      {
        name: 'sid-linux'
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

    assetsStorageAccountName: '<assetsStorageAccountName>'
    assetsStorageAccountContainerName: 'aibscripts'

    storageAccountFilesToUpload: [
      {
        name: 'Install-LinuxPowerShell.sh'
        value: loadTextContent('../scripts/uploads/linux/Install-LinuxPowerShell.sh')
      }
      {
        name: 'Initialize-LinuxSoftware.ps1'
        value: loadTextContent('../scripts/uploads/linux/Initialize-LinuxSoftware.ps1')
      }
      // {
      //   name: 'Install-WindowsPowerShell.ps1'
      //   value: loadTextContent('../scripts/uploads/windows/Install-WindowsPowerShell.ps1')
      // }
      // {
      //   name: 'Initialize-WindowsSoftware.ps1'
      //   value: loadTextContent('../scripts/uploads/windows/Initialize-WindowsSoftware.ps1')
      // }
    ]
    // Linux Example
    imageTemplateImageSource: {
      type: 'PlatformImage'
      publisher: 'canonical'
      offer: '0001-com-ubuntu-server-jammy'
      sku: '22_04-lts-gen2'
      version: 'latest'
      // Custom image example
      // type: 'SharedImageVersion'
      // imageVersionID: '${subscription().id}/resourceGroups/myRg/providers/Microsoft.Compute/galleries/<computeGalleryName>/images/sid-linux/versions/0.24470.675'
    }
    imageTemplateCustomizationSteps: [
      {
        type: 'Shell'
        name: 'PowerShell installation'
        scriptUri: 'https://<assetsStorageAccountName>.blob.${az.environment().suffixes.storage}/aibscripts/Install-LinuxPowerShell.sh'
      }
      {
        type: 'File'
        name: 'Initialize-LinuxSoftware'
        sourceUri: 'https://<assetsStorageAccountName>.blob.${az.environment().suffixes.storage}/aibscripts/Initialize-LinuxSoftware.ps1'
        destination: 'Initialize-LinuxSoftware.ps1'
      }
      {
        type: 'Shell'
        name: 'Software installation'
        inline: [
          'pwsh \'Initialize-LinuxSoftware.ps1\''
        ]
      }
    ]

    // Windows Example
    // computeGalleryImageDefinitions: [
    //     {
    //         name: 'sid-windows'
    //         osType: 'Windows'
    //         identifier: {
    //           publisher: 'devops'
    //           offer: 'devops_windows'
    //           sku: 'devops_windows_az'
    //         }
    //         osState: 'Generalized'
    //     }
    // ]
    // imageTemplateComputeGalleryImageDefinitionName: 'sid-windows'
    // imageTemplateImageSource: {
    //     type: 'PlatformImage'
    //     publisher: 'MicrosoftWindowsDesktop'
    //     offer: 'Windows-10'
    //     sku: '19h2-evd'
    //     version: 'latest'
    // }
    // imageTemplateCustomizationSteps: [
    //     {
    //         type: 'PowerShell'
    //         name: 'PowerShell installation'
    //         inline: [
    //             'Write-Output "Download"'
    //             'wget \'https://<assetsStorageAccountName>.blob.${environment().suffixes.storage}/aibscripts/Install-WindowsPowerShell.ps1?\' -O \'Install-WindowsPowerShell.ps1\''
    //             'Write-Output "Invocation"'
    //             '. \'Install-WindowsPowerShell.ps1\''
    //         ]
    //         runElevated: true
    //     }
    //     {
    //         type: 'File'
    //         name: 'Initialize-WindowsSoftware'
    //         sourceUri: 'https://<assetsStorageAccountName>.blob.${az.environment().suffixes.storage}/aibscripts/Initialize-WindowsSoftware.ps1'
    //         destination: 'Initialize-WindowsSoftware.ps1'
    //     }
    //     {
    //         type: 'PowerShell'
    //         name: 'Software installation'
    //         inline: [
    //             'wget \'https://<assetsStorageAccountName>.blob.${environment().suffixes.storage}/aibscripts/Initialize-WindowsSoftware.ps1?\' -O \'Initialize-WindowsSoftware.ps1\''
    //             'pwsh \'Initialize-WindowsSoftware.ps1\''
    //         ]
    //         runElevated: true
    //     }
    // ]
  }
}
