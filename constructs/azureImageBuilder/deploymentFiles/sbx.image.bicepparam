using '../templates/image.deploy.bicep'

//////////////////////////
//   Input Parameters   //
//////////////////////////
param deploymentsToPerform = 'All'

param location = 'WestEurope'

param computeGalleryName = 'aibgallery'

param computeGalleryImageDefinitions = [
    {
        hyperVGeneration: 'V2'
        name: 'sid-linux'
        osType: 'Linux'
        publisher: 'devops'
        offer: 'devops_linux'
        sku: 'devops_linux_az'
    }
]

param storageAccountName = 'shaibstorage'
param storageAccountContainerName = 'aibscripts'

param storageAccountFilesToUpload = {
    secureList: [
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
}

// Linux Example
param imageTemplateImageSource = {
    type: 'PlatformImage'
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-focal'
    sku: '20_04-lts-gen2'
    version: 'latest'
    // Custom image example
    // type: 'SharedImageVersion'
    // imageVersionID: '${subscription().id}/resourceGroups/myRg/providers/Microsoft.Compute/galleries/aibgallery/images/linux-sid/versions/0.24470.675'
}

param imageTemplateCustomizationSteps = [
    // {
    //     type: 'Shell'
    //     name: 'PowerShell installation'
    //     scriptUri: 'https://shaibstorage.blob.${az.environment().suffixes.storage}/aibscripts/LinuxInstallPowerShell.sh'
    // }
    // {
    //     type: 'File'
    //     name: 'LinuxPrepareMachine'
    //     sourceUri: 'https://shaibstorage.blob.${az.environment().suffixes.storage}/aibscripts/LinuxPrepareMachine.ps1'
    //     destination: 'LinuxPrepareMachine.ps1'
    // }
    // {
    //     type: 'Shell'
    //     name: 'Software installation'
    //     inline: [
    //         'pwsh \'LinuxPrepareMachine.ps1\''
    //     ]
    // }
]

param imageTemplateComputeGalleryImageDefinitionName = computeGalleryImageDefinitions[0].name
param imageTemplateResourceGroupName = 'agents-vmss-${computeGalleryImageDefinitions[0].name}-image-build-rg' // Should use image definition name to not conflict with other simulantious image builds

// @description('The generated name of the image template.')
// output imageTemplateName string = imageDeployment.outputs.imageTemplateName
