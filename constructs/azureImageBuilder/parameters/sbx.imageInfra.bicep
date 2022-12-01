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

///////////////////////////////
//   Deployment Properties   //
///////////////////////////////

// Resource Group
var rgParam = {
    name: 'agents-vmss-rg'
}

// User Assigned Identity
var msiParam = {
    name: 'aibMsi'
}

// User Assigned Identity Role Assignment on subscription scope
var msiRoleAssignmentParam = {
    roleDefinitionIdOrName: 'Contributor'
}

// Storage Account
var saParam = {
    name: 'shaibstorage'
    blobServices: {
        containers: [
            {
                name: 'aibscripts'
                publicAccess: 'None'
            }
        ]
    }
}

// Azure Compute Gallery
var acgParam = {
    name: 'aibgallery'
    images: [
        {
            hyperVGeneration: 'V2'
            name: 'linux-sid'
            osType: 'Linux'
            publisher: 'devops'
            offer: 'devops_linux'
            sku: 'devops_linux_az'
        }
        // Windows Example
        // {
        //     name: 'windows-sid'
        //     osType: 'Windows'
        //     publisher: 'devops'
        //     offer: 'devops_windows'
        //     sku: 'devops_windows_az'
        // }
    ]
}

/////////////////////////////
//   Template Deployment   //
/////////////////////////////
module imageInfraDeployment '../templates/imageInfra.deploy.bicep' = {
    name: '${uniqueString(deployment().name)}-imageInfra-sbx'
    params: {
        location: location
        rgParam: rgParam
        acgParam: acgParam
        msiParam: msiParam
        msiRoleAssignmentParam: msiRoleAssignmentParam
        saParam: saParam
        deploymentsToPerform: deploymentsToPerform
    }
}
