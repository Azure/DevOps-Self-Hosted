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
        [string] $ScaleSetResourceID,

        [Parameter(Mandatory = $false)]
        [string] $AuthorizeAllPipelines = $true,

        [Parameter(Mandatory = $false)]
        [string] $MaxCapacity = 10,

        [Parameter(Mandatory = $false)]
        [string] $DesiredIdle = 1,

        [Parameter(Mandatory = $false)]
        [string] $RecycleAfterEachUse = $false,

        [Parameter(Mandatory = $false)]
        [string] $AgentInteractiveUI = $false,

        [Parameter(Mandatory = $false)]
        [string] $MaxSavedNodeCount = 0,

        [Parameter(Mandatory = $false)]
        [string] $TimeToLiveMinutes = 15
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
            azureId              = $ScaleSetResourceID
            maxCapacity          = $MaxCapacity
            desiredIdle          = $DesiredIdle
            recycleAfterEachUse  = $RecycleAfterEachUse
            maxSavedNodeCount    = $MaxSavedNodeCount
            timeToLiveMinutes    = $TimeToLiveMinutes
            agentInteractiveUI   = $AgentInteractiveUI
        }

        $restInfo = Get-ConfigValue -token 'RESTElasticPoolCreate'
        $restInputObject = @{
            method = $restInfo.method
            uri    = '"{0}"' -f ($restInfo.uri -f [uri]::EscapeDataString($Organization), [uri]::EscapeDataString($PoolName), $ProjectId, $AuthorizeAllPipelines)
            body   = ConvertTo-Json $body -Depth 10 -Compress
        }
        if ($PSCmdlet.ShouldProcess(('REST command to create scale set agent pool [{0}] using scale set [{1}]' -f $PoolName, $ScaleSetResourceID), 'Invoke')) {

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
