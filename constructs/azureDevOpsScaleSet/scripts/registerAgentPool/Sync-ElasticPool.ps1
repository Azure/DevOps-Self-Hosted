<#
.SYNOPSIS
Register or update a given agent pool that links to a virtual machine scale set

.DESCRIPTION
Register or update a given agent pool that links to a virtual machine scale set

.PARAMETER PAT
Mandatory. The PAT token to use to interact with Azure DevOps.
If using the $(System.AccessToken), the 'Project Collection Build Service (<org>)' must at least:
- Be added with level 'User' to the 'Project Settings / Pipelines / Service Connections' security
- Be added with level 'Creator' to the 'Project Settings / Pipelines / Agent pools' security

.PARAMETER Organization
Mandatory. The organization to register/update the agent pool in

.PARAMETER ProjectId
Mandatory. The project to register/update the agent pool in

.PARAMETER VMSSName
Mandatory. The name of the virtual machine scale set to register with

.PARAMETER VMSSResourceGroupName
Mandatory. The name of the resource group containing virtual machine scale set to register with

.PARAMETER ServiceConnectionName
Mandatory. The name of the service connection with access to the subscription containing the virtual machine scale set to register with

.PARAMETER AgentPoolProperties
Mandatory. The agent pool configuration. For example the desired idle time, maximum scale out, etc.
Must be in format:

@{
    ScaleSetPoolName      = 'myPool'
    DesiredIdle           = 1
    MaxCapacity           = 10
    TimeToLiveMinutes     = 15
    MaxSavedNodeCount     = 0
    RecycleAfterEachUse   = $false
    AgentInteractiveUI    = $false
    AuthorizeAllPipelines = $true
}

.EXAMPLE
$inputObject = @{
    PAT                   = '$(System.AccessToken)'
    Organization          = 'contoso'
    Project               = 'myProject'
    ServiceConnectionName = 'myConnection'
    VMSSName              = 'my-scaleset'
    VMSSResourceGroupName = 'my-scaleset-rg'
    AgentPoolProperties   = @{
        ScaleSetPoolName      = 'myPool'
        DesiredIdle           = 1
        MaxCapacity           = 10
        TimeToLiveMinutes     = 15
        MaxSavedNodeCount     = 0
        RecycleAfterEachUse   = $false
        AgentInteractiveUI    = $false
        AuthorizeAllPipelines = $true
    }
}
Sync-ElasticPool @inputObject

Register/update scale set agent pool 'myPool', using scale set [my-scaleset-rg|my-scaleset] and the provided configuration, in Azure DevOps project [contoso|myProject]

.EXAMPLE
$inputObject = @{
    PAT                   = '$(System.AccessToken)'
    Organization          = 'contoso'
    Project               = 'myProject'
    ServiceConnectionName = 'myConnection'
    VMSSName              = 'my-scaleset'
    VMSSResourceGroupName = 'my-scaleset-rg'
    AgentPoolProperties   = @{
        ScaleSetPoolName      = 'myPool'
    }
}
Sync-ElasticPool @inputObject

Register/update scale set agent pool 'myPool', using scale set [my-scaleset-rg|my-scaleset] with the default configuration, in Azure DevOps project [contoso|myProject]
#>
function Sync-ElasticPool {

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $PAT,

        [Parameter(Mandatory = $true)]
        [string] $Organization,

        [Parameter(Mandatory = $true)]
        [string] $Project,

        [Parameter(Mandatory = $true)]
        [string] $VMSSName,

        [Parameter(Mandatory = $true)]
        [string] $VMSSResourceGroupName,

        [Parameter(Mandatory = $true)]
        [string] $ServiceConnectionName,

        [Parameter(Mandatory = $true)]
        [hashtable] $AgentPoolProperties
    )

    begin {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)

        # Install required modules
        $currentVerbosePreference = $VerbosePreference
        $VerbosePreference = 'SilentlyContinue'
        $requiredModules = @(
            'Az.Compute'
        )
        foreach ($moduleName in $requiredModules) {
            if (-not ($installedModule = Get-Module $moduleName -ListAvailable)) {
                Install-Module $moduleName -Repository 'PSGallery' -Force -Scope 'CurrentUser'
                if ($installed = Get-Module -Name $moduleName -ListAvailable) {
                    Write-Verbose ('Installed module [{0}] with version [{1}]' -f $installed.Name, $installed.Version) -Verbose
                }
            } else {
                Write-Verbose ('Module [{0}] already installed in version [{1}]' -f $installedModule.Name, $installedModule.Version) -Verbose
            }
        }
        $VerbosePreference = $currentVerbosePreference

        # Load helper
        . (Join-Path $PSScriptRoot 'Get-Project.ps1')
        . (Join-Path $PSScriptRoot 'Get-Endpoint.ps1')
        . (Join-Path $PSScriptRoot 'Get-ElasticPool.ps1')
        . (Join-Path $PSScriptRoot 'New-ElasticPool.ps1')
        . (Join-Path $PSScriptRoot 'Set-ElasticPool.ps1')
    }

    process {

        if (-not [String]::IsNullOrEmpty($PAT)) {
            Write-Verbose 'Login to AzureDevOps via PAT token' -Verbose
            $env:AZURE_DEVOPS_EXT_PAT = $PAT
        }

        if (-not ($vmss = Get-AzVmss -Name $VMSSName -ResourceGroupName $VMSSResourceGroupName)) {
            throw ('Unable to find virtual machine scale set [{0}] in resource group [{1}]' -f $VMSSName, $VMSSResourceGroupName)
        } else {
            Write-Verbose ('Found virtual machine scale set [{0}] in resource group [{1}]' -f $VMSSName, $VMSSResourceGroupName) -Verbose
        }

        if (-not ($foundProject = Get-Project -Organization $Organization -Project $project)) {
            throw ('Unable to find Azure DevOps project [{0}] in organization [{1}]' -f $project, $Organization)
        } else {
            Write-Verbose ('Found Azure DevOps project [{0}] in organization [{1}]' -f $project, $Organization) -Verbose
        }

        $serviceEndpoints = Get-Endpoint -Organization $Organization -Project $project
        if (-not ($serviceEndpoint = $serviceEndpoints | Where-Object { $_.name -eq $serviceConnectionName })) {
            throw ('Unable to find Azure DevOps service connection [{0}] in project [{1}|{2}]' -f $serviceConnectionName, $Organization, $Project)
        } else {
            Write-Verbose ('Found Azure DevOps service connect [{0}] in project [{1}] of organization [{2}]' -f $serviceConnectionName, $project, $Organization) -Verbose
        }

        $elasticPools = Get-ElasticPool -Organization $Organization -Project $project
        if (-not ($elasticPool = $elasticPools | Where-Object { $_.azureId -eq $vmss.Id })) {
            Write-Verbose ('Agent pool for scale set [{0}] in resource group [{1}] not registered, creating new.' -f $vmss.Name, $vmss.ResourceGroupName) -Verbose
            $inputObject = @{
                Organization      = $Organization
                ProjectId         = $foundProject.id
                PoolName          = $AgentPoolProperties.ScaleSetPoolName
                ServiceEndpointId = $serviceEndpoint.id
                VMSSResourceID    = $vmss.Id
                VMSSOSType        = $vmss.VirtualMachineProfile.StorageProfile.OsDisk.OsType
            }
            if ($AgentPoolProperties.ContainsKey('AuthorizeAllPipelines')) { $inputObject['AuthorizeAllPipelines'] = $AgentPoolProperties.AuthorizeAllPipelines }
            if ($AgentPoolProperties.ContainsKey('MaxCapacity')) { $inputObject['MaxCapacity'] = $AgentPoolProperties.MaxCapacity }
            if ($AgentPoolProperties.ContainsKey('DesiredIdle')) { $inputObject['DesiredIdle'] = $AgentPoolProperties.DesiredIdle }
            if ($AgentPoolProperties.ContainsKey('RecycleAfterEachUse')) { $inputObject['RecycleAfterEachUse'] = $AgentPoolProperties.RecycleAfterEachUse }
            if ($AgentPoolProperties.ContainsKey('MaxSavedNodeCount')) { $inputObject['MaxSavedNodeCount'] = $AgentPoolProperties.MaxSavedNodeCount }
            if ($AgentPoolProperties.ContainsKey('TimeToLiveMinutes')) { $inputObject['TimeToLiveMinutes'] = $AgentPoolProperties.TimeToLiveMinutes }
            if ($AgentPoolProperties.ContainsKey('AgentInteractiveUI')) { $inputObject['AgentInteractiveUI'] = $AgentPoolProperties.AgentInteractiveUI }

            if ($PSCmdlet.ShouldProcess(('Agent pool [{0}]' -f $AgentPoolProperties.ScaleSetPoolName), 'Create')) {
                New-ElasticPool @inputObject
            }
        } else {
            Write-Verbose ('Agent pool [{0}] with ID [{1}] for scale set [{2}] in resource group [{3}] already exists. Updating.' -f $AgentPoolProperties.ScaleSetPoolName, $elasticPool.poolId, $vmss.Name, $vmss.ResourceGroupName) -Verbose
            $inputObject = @{
                Organization   = $Organization
                ScaleSetPoolId = $elasticPool.poolId
                VMSSResourceID = $vmss.Id
                VMSSOSType     = $vmss.VirtualMachineProfile.StorageProfile.OsDisk.OsType
            }
            if ($AgentPoolProperties.ContainsKey('MaxCapacity')) { $inputObject['MaxCapacity'] = $AgentPoolProperties.MaxCapacity }
            if ($AgentPoolProperties.ContainsKey('DesiredIdle')) { $inputObject['DesiredIdle'] = $AgentPoolProperties.DesiredIdle }
            if ($AgentPoolProperties.ContainsKey('RecycleAfterEachUse')) { $inputObject['RecycleAfterEachUse'] = $AgentPoolProperties.RecycleAfterEachUse }
            if ($AgentPoolProperties.ContainsKey('MaxSavedNodeCount')) { $inputObject['MaxSavedNodeCount'] = $AgentPoolProperties.MaxSavedNodeCount }
            if ($AgentPoolProperties.ContainsKey('TimeToLiveMinutes')) { $inputObject['TimeToLiveMinutes'] = $AgentPoolProperties.TimeToLiveMinutes }
            if ($AgentPoolProperties.ContainsKey('AgentInteractiveUI')) { $inputObject['AgentInteractiveUI'] = $AgentPoolProperties.AgentInteractiveUI }

            if ($PSCmdlet.ShouldProcess(('Agent pool [{0}]' -f $AgentPoolProperties.ScaleSetPoolName), 'Update')) {
                Set-ElasticPool @inputObject
            }
        }
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
