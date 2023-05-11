targetScope = 'subscription'

//////////////////////////
//   Input Parameters   //
//////////////////////////
@description('Optional. A parameter to control which deployments should be executed')
@allowed([
    'All'
    'Only infrastructure'
    'Only storage & image'
    'Only image'
])
param deploymentsToPerform string = 'All'

@description('Optional. Specifies the location for resources.')
param location string = 'WestEurope'

/////////////////////////////
//   Template Deployment   //
/////////////////////////////

module imageDeployment '../templates/image.deploy.bicep' = {
    name: '${uniqueString(deployment().name)}-image-sbx'
    params: {
        location: location
        deploymentsToPerform: deploymentsToPerform
        computeGalleryName: 'aibgallery'
        storageAccountName: 'shaibstorage'
        storageAccountContainerName: 'aibscripts'

        storageAccountFilesToUpload: [
            {
                name: 'script_LinuxInstallPowerShell_sh'
                value: loadTextContent('../scripts/Uploads/linux/LinuxInstallPowerShell.sh')
            }
            {
                name: 'script_LinuxPrepareMachine_ps1'
                value: loadTextContent('../scripts/Uploads/linux/LinuxPrepareMachine.ps1')
            }
            // {
            //     name: 'script_WindowsInstallPowerShell_ps1'
            //     value: loadTextContent('../scripts/Uploads/windows/WindowsInstallPowerShell.ps1')
            // }
            // {
            //     name: 'script_WindowsPrepareMachine_ps1'
            //     value: loadTextContent('../scripts/Uploads/windows/WindowsPrepareMachine.ps1')
            // }
        ]

        // Linux Example
        imageTemplateImageSource: {
            type: 'PlatformImage'
            publisher: 'Canonical'
            offer: '0001-com-ubuntu-server-focal'
            sku: '20_04-lts-gen2'
            version: 'latest'
            // Custom image example
            // type: 'SharedImageVersion'
            // imageVersionID: '${subscription().id}/resourceGroups/myRg/providers/Microsoft.Compute/galleries/aibgallery/images/linux-sid/versions/0.24470.675'
        }
        imageTemplateCustomizationSteps: [
            {
                type: 'Shell'
                name: 'PowerShell installation'
                scriptUri: 'https://shaibstorage.blob.${az.environment().suffixes.storage}/aibscripts/LinuxInstallPowerShell.sh'
            }
            {
                type: 'File'
                name: 'LinuxPrepareMachine'
                sourceUri: 'https://shaibstorage.blob.${az.environment().suffixes.storage}/aibscripts/LinuxPrepareMachine.ps1'
                destination: 'LinuxPrepareMachine.ps1'
            }
            {
                type: 'Shell'
                name: 'Software installation'
                inline: [
                    'pwsh \'LinuxPrepareMachine.ps1\''
                ]
            }
            
        ]
        imageTemplateComputeGalleryImageDefinitionName: 'linux-sid'

        // Windows Example
        // imageTemplateComputeGalleryImageDefinitionName: 'windows-sid'
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
        //             'wget \'https://shaibstorage.blob.${environment().suffixes.storage}/aibscripts/WindowsInstallPowerShell.ps1?\' -O \'WindowsInstallPowerShell.ps1\''
        //             'Write-Output "Invocation"'
        //             '. \'WindowsInstallPowerShell.ps1\''
        //         ]
        //         runElevated: true
        //     }
        //     {
        //         type: 'File'
        //         name: 'WindowsPrepareMachine'
        //         sourceUri: 'https://shaibstorage.blob.${az.environment().suffixes.storage}/aibscripts/WindowsPrepareMachine.ps1'
        //         destination: 'WindowsPrepareMachine.ps1'
        //     }
        //     {
        //         type: 'PowerShell'
        //         name: 'Software installation'
        //         inline: [
        //             'wget \'https://shaibstorage.blob.${environment().suffixes.storage}/aibscripts/WindowsPrepareMachine.ps1?\' -O \'WindowsPrepareMachine.ps1\''
        //             'pwsh \'WindowsPrepareMachine.ps1\''
        //         ]
        //         runElevated: true
        //     }
        // ]
    }
}

@description('The generated name of the image template.')
output imageTemplateName string = imageDeployment.outputs.imageTemplateName
