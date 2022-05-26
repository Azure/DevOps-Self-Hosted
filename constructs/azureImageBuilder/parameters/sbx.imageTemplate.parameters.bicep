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

///////////////////////////////
//   Deployment Properties   //
///////////////////////////////

// Misc
resource existingStorage 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
    name: 'shaibforkstorage'
    scope: resourceGroup(subscription().subscriptionId, rgParam.name)
}
var sasConfig = {
    signedResourceTypes: 'o'
    signedPermission: 'r'
    signedServices: 'b'
    signedExpiry: dateTimeAdd(baseTime, 'PT1H')
    signedProtocol: 'https'
}
var sasKey = existingStorage.listAccountSas(existingStorage.apiVersion, sasConfig).accountSasToken

// Resource Group
var rgParam = {
    name: 'agents-vmss-rg'
}

// Image Template
var itParam = {
    name: 'lin_it'
    userMsiName: 'aibMsi'
    userMsiResourceGroup: rgParam.name
    imageSource: {
        type: 'PlatformImage'
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
        // Custom image example
        // type: 'SharedImageVersion'
        // imageVersionID: '${subscription().id}/resourceGroups/${rgParam.name}/providers/Microsoft.Compute/galleries/aibgallery/images/linux-sid/versions/0.24470.675'
    }
    customizationSteps: [
        {
            type: 'Shell'
            name: 'PowerShell installation'
            scriptUri: 'https://shaibforkstorage.blob.${environment().suffixes.storage}/aibscripts/LinuxInstallPowerShell.sh?${sasKey}'
        }
        {
            type: 'Shell'
            name: 'Prepare software installation'
            inline: [
                'wget \'https://shaibforkstorage.blob.${environment().suffixes.storage}/aibscripts/LinuxPrepareMachine.ps1?${sasKey}\' -O \'LinuxPrepareMachine.ps1\''
                'sed -i \'s/\r$//\' \'LinuxPrepareMachine.ps1\''
                'pwsh \'LinuxPrepareMachine.ps1\''
            ]
        }
    ]
    sigImageDefinitionId: '${subscription().id}/resourceGroups/${rgParam.name}/providers/Microsoft.Compute/galleries/aibgallery/images/linux-sid'
    // Windows example
    // imageSource: {
    //     type: 'PlatformImage'
    //     publisher: 'MicrosoftWindowsDesktop'
    //     offer: 'Windows-10'
    //     sku: '19h2-evd'
    //     version: 'latest'
    // }
    // customizationSteps: [
    //     {
    //         type: 'PowerShell'
    //         name: 'Software installation'
    //         scriptUri: 'https://shaibforkstorage.blob.core.windows.net/aibscripts/WindowsPrepareMachine.ps1?${sasKey}'
    //         runElevated: true
    //     }
    // ]
    // sigImageDefinitionId: '${subscription().id}/resourceGroups/${rgParam.name}/providers/Microsoft.Compute/galleries/aibgallery/images/windows-sid'
}

/////////////////////////////
//   Template Deployment   //
/////////////////////////////
module scaleSetDeployment '../templates/imageTemplate.deploy.bicep' = {
    name: '${uniqueString(deployment().name)}-imageInfra-sbx'
    params: {
        location: location
        rgParam: rgParam
        itParam: itParam
        deploymentsToPerform: deploymentsToPerform
    }
}

@description('The generated name of the image template')
output imageTempateName string = scaleSetDeployment.outputs.imageTempateName
