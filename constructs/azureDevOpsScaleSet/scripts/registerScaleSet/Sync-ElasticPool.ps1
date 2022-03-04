function Sync-ElasticPool {

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Organization,

        [Parameter(Mandatory = $true)]
        [string] $Project,

        [Parameter(Mandatory = $true)]
        [string] $ServiceConnectionName,

        [Parameter(Mandatory = $true)]
        [hashtable] $AgentPoolProperties
    )

    begin {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)

        # Load helper
        . (Join-Path $PSScriptRoot 'Get-Project.ps1')
        . (Join-Path $PSScriptRoot 'Get-Endpoint.ps1')
        . (Join-Path $PSScriptRoot 'Get-ElasticPool.ps1')
        . (Join-Path $PSScriptRoot 'New-ElasticPool.ps1')
        . (Join-Path $PSScriptRoot 'Set-ElasticPool.ps1')
    }

    process {
        $foundProject = Get-Project -Organization $Organization -Project $project

        $serviceEndpoints = Get-Endpoint -Organization $Organization -Project $project
        $serviceEndpoint = $serviceEndpoints | Where-Object { $_.name -eq $serviceConnectionName }

        $elasticPools = Get-ElasticPool -Organization $Organization -Project $project
        if (-not ($elasticPool = $elasticPools | Where-Object { $_.azureId -eq $AgentPoolProperties.scaleSetResourceId })) {
            Write-Verbose ('Agent pool for scale set [{0}] in resource group [{1}] not registered, creating new.' -f $AgentPoolProperties.scaleSetResourceId.Split('/')[-1], $AgentPoolProperties.scaleSetResourceId.Split('/')[4])
            $inputObject = @{
                Organization          = $Organization
                ProjectId             = $foundProject.id
                PoolName              = $ScaleSetPoolName
                ServiceEndpointId     = $serviceEndpoint.id
                ScaleSetResourceID    = $scaleSetResourceId
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
                ScaleSetResourceID  = $scaleSetResourceId
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
