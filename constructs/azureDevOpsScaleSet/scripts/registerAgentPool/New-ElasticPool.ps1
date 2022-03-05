<#
.SYNOPSIS
Register a new Azure DevOps elastic pool (virtual machine scale set agent pool) in the given Azure DevOps project

.DESCRIPTION
Register a new Azure DevOps elastic pool (virtual machine scale set agent pool) in the given Azure DevOps project

.PARAMETER Organization
Mandatory. The organization to register the agent pool in

.PARAMETER ProjectId
Mandatory. The project to register the agent pool in

.PARAMETER PoolName
Mandatory. The name of the agent pool

.PARAMETER ServiceEndpointId
Mandatory. The ID of the service connection that has access to the Azure subscription that contains the virtual machine scale set

.PARAMETER VMSSResourceID
Mandatory. The resource ID of the virtual machine scale set to register with

.PARAMETER VMSSOSType
Mandatory. The OSType of the virtual machine scale set to register with

.PARAMETER AuthorizeAllPipelines
Optional. Setting to determine if all pipelines are authorized to use this TaskAgentPool by default. Defaults to 'true'

.PARAMETER MaxCapacity
Optional. Maximum number of nodes that will exist in the elastic pool. Defaults to '10'

.PARAMETER DesiredIdle
Optional. Number of agents to have ready waiting for jobs. Defaults to '1'

.PARAMETER RecycleAfterEachUse
Optional. Discard node after each job completes. Defaults to 'false'

.PARAMETER AgentInteractiveUI
Optional. Set whether agents should be configured to run with interactive UI. Defaults to 'false'

.PARAMETER MaxSavedNodeCount
Optional. Keep nodes in the pool on failure for investigation. Defaults to '0'

.PARAMETER TimeToLiveMinutes
Optional. The minimum time in minutes to keep idle agents alive. Defaults to '15'

.EXAMPLE
$inputObject = @{
    Organization      = 'contoso'
    ProjectId         = 43
    PoolName          = 'myPool'
    ServiceEndpointId = '11111-1111-11111-1111-1111111'
    VMSSResourceID    = '/subscriptions/<subscriptionId>/resourceGroups/agents-vmss-rg/providers/Microsoft.Compute/virtualMachineScaleSets/agent-scaleset'
    VMSSOSType        = 'Linux'
}
New-ElasticPool @inputObject

Register virtual machine scale set 'agent-scaleset' as agent pool 'myPool' in project [contoso|43] using the default configuration
#>
function New-ElasticPool {

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Organization,

        [Parameter(Mandatory = $true)]
        [string] $ProjectId,

        [Parameter(Mandatory = $true)]
        [string] $PoolName,

        [Parameter(Mandatory = $true)]
        [string] $ServiceEndpointId,

        [Parameter(Mandatory = $true)]
        [string] $VMSSResourceID,

        [Parameter(Mandatory = $true)]
        [string] $VMSSOSType,

        [Parameter(Mandatory = $false)]
        [bool] $AuthorizeAllPipelines = $true,

        [Parameter(Mandatory = $false)]
        [int] $MaxCapacity = 10,

        [Parameter(Mandatory = $false)]
        [int] $DesiredIdle = 1,

        [Parameter(Mandatory = $false)]
        [bool] $RecycleAfterEachUse = $false,

        [Parameter(Mandatory = $false)]
        [bool] $AgentInteractiveUI = $false,

        [Parameter(Mandatory = $false)]
        [int] $MaxSavedNodeCount = 0,

        [Parameter(Mandatory = $false)]
        [int] $TimeToLiveMinutes = 15
    )

    begin {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)

        # Load helper
        . (Join-Path -Path (Split-Path $PSScriptRoot -Parent) 'misc' 'Get-ConfigValue.ps1')
        . (Join-Path -Path (Split-Path $PSScriptRoot -Parent) 'misc' 'Invoke-RESTCommand.ps1')
    }

    process {

        $body = @{
            serviceEndpointId    = $ServiceEndpointId
            serviceEndpointScope = $ProjectId
            azureId              = $VMSSResourceID
            maxCapacity          = $MaxCapacity
            desiredIdle          = $DesiredIdle
            recycleAfterEachUse  = $RecycleAfterEachUse
            maxSavedNodeCount    = $MaxSavedNodeCount
            timeToLiveMinutes    = $TimeToLiveMinutes
            agentInteractiveUI   = $AgentInteractiveUI
            osType               = $VMSSOSType
        }

        $restInfo = Get-ConfigValue -token 'RESTElasticPoolCreate'
        $restInputObject = @{
            method = $restInfo.method
            uri    = '"{0}"' -f ($restInfo.uri -f [uri]::EscapeDataString($Organization), [uri]::EscapeDataString($PoolName), $ProjectId, $AuthorizeAllPipelines)
            body   = ConvertTo-Json $body -Depth 10 -Compress
        }
        if ($PSCmdlet.ShouldProcess(('REST command to create scale set agent pool [{0}] using scale set [{1}]' -f $PoolName, $VMSSResourceID), 'Invoke')) {

            $response = Invoke-RESTCommand @restInputObject

            if (-not [String]::IsNullOrEmpty($response.errorCode)) {
                Write-Error ('Failed to create scale set agent pool because of [{0} - {1}]' -f $response.typeKey, $response.message)
                return
            }

            Write-Verbose ('Successfully created scale set agent pool [{0}] with id [{1}]' -f $response.agentpool.name, $response.agentpool.id) -Verbose
        }
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
