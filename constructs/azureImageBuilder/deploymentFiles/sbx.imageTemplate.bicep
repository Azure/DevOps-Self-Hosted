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
param deploymentsToPerform string = 'Only storage & image'

@description('Optional. Specifies the location for resources.')
param location string = 'WestEurope'

@description('Generated. Do not provide a value! This date value is used to generate a registration token.')
param baseTime string = utcNow('u')

@description('Required. The name of the Resource Group containing the Virtual Network.')
param virtualNetworkResourceGroupName string

@description('Required. The name of the Virtual Network.')
param virtualNetworkName string

@description('Required. The name of the Image Template Virtual Network Subnet to create.')
param virtualNetworkSubnetName string

///////////////////////////////
//   Deployment Properties   //
///////////////////////////////

// Misc
resource existingStorage 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
    name: '<YourStorageAccount>'
    scope: resourceGroup(subscription().subscriptionId, 'agents-vmss-rg')
}
var sasConfig = {
    signedResourceTypes: 'o'
    signedPermission: 'r'
    signedServices: 'b'
    signedExpiry: dateTimeAdd(baseTime, 'PT1H')
    signedProtocol: 'https'
}
var sasKey = existingStorage.listAccountSas(existingStorage.apiVersion, sasConfig).accountSasToken

/////////////////////////////
//   Template Deployment   //
/////////////////////////////
resource imageTemplateVNET 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
    name: virtualNetworkName

    resource imageTemplateSubnet 'subnets@2022-07-01' existing = {
        name: virtualNetworkSubnetName
    }

    scope: resourceGroup(virtualNetworkResourceGroupName)
}

module imageTemplateDeployment '../templates/imageTemplate.deploy.bicep' = {
    name: '${uniqueString(deployment().name)}-imageInfra-sbx'
    params: {
        location: location
        deploymentsToPerform: deploymentsToPerform
        imageTemplateComputeGalleryName: '<YourComputeGallery>'
        imageTemplateSubnetResourceId: imageTemplateVNET::imageTemplateSubnet.id

        // Linux Example
        imageTemplateImageSource: {
            type: 'PlatformImage'
            publisher: 'Canonical'
            offer: '0001-com-ubuntu-server-focal'
            sku: '20_04-lts-gen2'
            version: 'latest'
            // Custom image example
            // type: 'SharedImageVersion'
            // imageVersionID: '${subscription().id}/resourceGroups/myRg/providers/Microsoft.Compute/galleries/<YourComputeGallery>/images/linux-sid/versions/0.24470.675'
        }
        imageTemplateCustomizationSteps: [
            {
                type: 'Shell'
                name: 'PowerShell installation'
                scriptUri: 'https://<YourStorageAccount>.blob.${environment().suffixes.storage}/aibscripts/LinuxInstallPowerShell.sh?${sasKey}'
            }
            {
                type: 'Shell'
                name: 'Software installation'
                inline: [
                    'wget \'https://<YourStorageAccount>.blob.${environment().suffixes.storage}/aibscripts/LinuxPrepareMachine.ps1?${sasKey}\' -O \'LinuxPrepareMachine.ps1\''
                    'sed -i \'s/\r$//\' \'LinuxPrepareMachine.ps1\''
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
        //             'wget \'https://<YourStorageAccount>.blob.${environment().suffixes.storage}/aibscripts/WindowsInstallPowerShell.ps1?${sasKey}\' -O \'WindowsInstallPowerShell.ps1\''
        //             'Write-Output "Invocation"'
        //             '. \'WindowsInstallPowerShell.ps1\''
        //         ]
        //         runElevated: true
        //     }
        //     {
        //         type: 'PowerShell'
        //         name: 'Software installation'
        //         inline: [
        //             'wget \'https://<YourStorageAccount>.blob.${environment().suffixes.storage}/aibscripts/WindowsPrepareMachine.ps1?${sasKey}\' -O \'WindowsPrepareMachine.ps1\''
        //             'pwsh \'WindowsPrepareMachine.ps1\''
        //         ]
        //         runElevated: true
        //     }
        // ]
    }
}

@description('The generated name of the Image Template.')
output imageTempateName string = imageTemplateDeployment.outputs.imageTempateName
