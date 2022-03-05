<#
.SYNOPSIS
Update an existing Azure DevOps elastic pool (virtual machine scale set agent pool)

.DESCRIPTION
Update an existing Azure DevOps elastic pool (virtual machine scale set agent pool)

.PARAMETER Organization
Mandatory. The organization to update the agent pool in

.PARAMETER ProjectId
Mandatory. The project to update the agent pool in

.PARAMETER VMSSResourceID
Mandatory. The resource ID of the virtual machine scale set to update

.PARAMETER VMSSOSType
Parameter description

.PARAMETER MaxCapacity
Parameter description

.PARAMETER DesiredIdle
Parameter description

.PARAMETER RecycleAfterEachUse
Parameter description

.PARAMETER AgentInteractiveUI
Parameter description

.PARAMETER MaxSavedNodeCount
Parameter description

.PARAMETER TimeToLiveMinutes
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Set-ElasticPool {

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Organization,

        [Parameter(Mandatory = $true)]
        [int] $ScaleSetPoolId,

        [Parameter(Mandatory = $true)]
        [string] $VMSSResourceID,

        [Parameter(Mandatory = $true)]
        [string] $VMSSOSType,

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
            recycleAfterEachUse = $RecycleAfterEachUse
            maxSavedNodeCount   = $MaxSavedNodeCount
            maxCapacity         = $MaxCapacity
            desiredIdle         = $DesiredIdle
            timeToLiveMinutes   = $TimeToLiveMinutes
            agentInteractiveUI  = $AgentInteractiveUI
            azureId             = $VMSSResourceID
            osType              = $VMSSOSType
        }

        $restInfo = Get-ConfigValue -token 'RESTElasticPoolUpdate'
        $restInputObject = @{
            method = $restInfo.method
            uri    = '"{0}"' -f ($restInfo.uri -f [uri]::EscapeDataString($Organization), $ScaleSetPoolId)
            body   = ConvertTo-Json $body -Depth 10 -Compress
        }
        if ($PSCmdlet.ShouldProcess(('REST command to update scale set agent pool for scale set [{0}]' -f $VMSSResourceID), 'Invoke')) {

            $response = Invoke-RESTCommand @restInputObject

            if (-not [String]::IsNullOrEmpty($response.errorCode)) {
                Write-Error ('Failed to update scale set agent pool with id [{1}] for virtual machine scale set [{1}] because of [{2} - {3}]' -f $ScaleSetPoolId, $VMSSResourceID.Split('/')[-1], $response.typeKey, $response.message)
                return
            }

            Write-Verbose ('Successfully updated scale set agent pool with ID [{0}] for virtual machine scale set [{1}]' -f $reponse.poolId, $response.azureId.Split('/')[-1]) -Verbose
        }
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
