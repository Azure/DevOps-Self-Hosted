function Set-ElasticPool {

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Organization,

        [Parameter(Mandatory = $true)]
        [string] $ScaleSetPoolId,

        [Parameter(Mandatory = $true)]
        [string] $ScaleSetResourceID,

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
            recycleAfterEachUse = $RecycleAfterEachUse
            maxSavedNodeCount   = $MaxSavedNodeCount
            maxCapacity         = $MaxCapacity
            desiredIdle         = $DesiredIdle
            timeToLiveMinutes   = $TimeToLiveMinutes
            agentInteractiveUI  = $AgentInteractiveUI
        }

        $restInfo = Get-ConfigValue -token 'RESTElasticPoolUpdate'
        $restInputObject = @{
            method = $restInfo.method
            uri    = '"{0}"' -f ($restInfo.uri -f [uri]::EscapeDataString($Organization), $ScaleSetPoolId)
            body   = ConvertTo-Json $body -Depth 10 -Compress
        }
        if ($PSCmdlet.ShouldProcess(('REST command to update scale set agent pool for scale set [{0}]' -f $ScaleSetResourceID), 'Invoke')) {

            $response = Invoke-RESTCommand @restInputObject

            if (-not [String]::IsNullOrEmpty($response.errorCode)) {
                Write-Error ('Failed to update scale set agent pool with id [{1}] for virtual machine scale set [{1}] because of [{2} - {3}]' -f $ScaleSetPoolId, $ScaleSetResourceID.Split('/')[-1], $response.typeKey, $response.message)
                return
            }

            Write-Verbose ('Successfully updated scale set agent pool with ID [{0}] for virtual machine scale set [{1}]' -f $reponse.poolId, $response.azureId.Split('/')[-1]) -Verbose
        }
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
