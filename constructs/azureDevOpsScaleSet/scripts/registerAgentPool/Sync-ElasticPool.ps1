function Sync-ElasticPool {

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
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
            'Az.Resources'
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

        if (-not ($vmss = Get-AzResource -Name $VMSSName -ResourceGroupName $VMSSResourceGroupName -ResourceType 'Microsoft.Compute/virtualMachineScaleSets')) {
            throw ('Unable to find virtual machine scale set [{0}] in resource group [{1}]' -f $VMSSName, $VMSSResourceGroupName)
        }

        if (-not ($foundProject = Get-Project -Organization $Organization -Project $project)) {
            throw ('Unable to find Azure DevOps project [{0}] in organization [{1}]' -f $project, $Organization)
        }

        $serviceEndpoints = Get-Endpoint -Organization $Organization -Project $project
        if (-not ($serviceEndpoint = $serviceEndpoints | Where-Object { $_.name -eq $serviceConnectionName })) {
            throw ('Unable to find Azure DevOps service connection [{0}] in project [{1}|{2}]' -f $serviceConnectionName, $Organization, $Project)
        }

        $elasticPools = Get-ElasticPool -Organization $Organization -Project $project
        if (-not ($elasticPool = $elasticPools | Where-Object { $_.azureId -eq $vmss.resourceId })) {
            Write-Verbose ('Agent pool for scale set [{0}] in resource group [{1}] not registered, creating new.' -f $vmss.Name, $vmss.ResourceGroupName)
            $inputObject = @{
                Organization          = $Organization
                ProjectId             = $foundProject.id
                PoolName              = $ScaleSetPoolName
                ServiceEndpointId     = $serviceEndpoint.id
                ScaleSetResourceID    = $vmss.ResourceId
                AuthorizeAllPipelines = $AgentPoolProperties.AuthorizeAllPipelines
                MaxCapacity           = $AgentPoolProperties.MaxCapacity
                DesiredIdle           = $AgentPoolProperties.DesiredIdle
                RecycleAfterEachUse   = $AgentPoolProperties.RecycleAfterEachUse
                MaxSavedNodeCount     = $AgentPoolProperties.MaxSavedNodeCount
                TimeToLiveMinutes     = $AgentPoolProperties.TimeToLiveMinutes
            }
            if ($PSCmdlet.ShouldProcess(('Agent pool [{0}]' -f $ScaleSetPoolName), 'Create')) {
                New-ElasticPool @inputObject
            }
        } else {
            Write-Verbose 'Agent pool already registered, updating.'
            $inputObject = @{
                Organization        = $Organization
                ScaleSetPoolId      = $elasticPool.Id
                ScaleSetResourceID  = $vmss.ResourceId
                MaxCapacity         = $AgentPoolProperties.MaxCapacity
                DesiredIdle         = $AgentPoolProperties.DesiredIdle
                RecycleAfterEachUse = $AgentPoolProperties.RecycleAfterEachUse
                MaxSavedNodeCount   = $AgentPoolProperties.MaxSavedNodeCount
                TimeToLiveMinutes   = $AgentPoolProperties.TimeToLiveMinutes
            }
            if ($PSCmdlet.ShouldProcess(('Agent pool [{0}]' -f $ScaleSetPoolName), 'Update')) {
                Set-ElasticPool @inputObject
            }
        }
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
