<#
.SYNOPSIS
Link a pool registered on an organization level to a specific project

.DESCRIPTION
Link a pool registered on an organization level to a specific project

.PARAMETER Organization
Mandatory. The organization that contains the project to register the pool in

.PARAMETER Project
Mandatory. The project to register the pool in

.PARAMETER PoolName
Mandatory. The name of the pool to register

.PARAMETER PoolId
Mandatory. The ID of the pool to register

.EXAMPLE
Set-ElasticPoolRegistrationInProject -Organization 'contoso' -Project 'myProject' -poolName 'myPool' -poolId 16

Register the pool 'myPool' to project [contoso|myProject]
#>
function Set-ElasticPoolRegistrationInProject {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Organization,

        [Parameter(Mandatory = $true)]
        [string] $Project,

        [Parameter(Mandatory = $true)]
        [string] $PoolName,

        [Parameter(Mandatory = $true)]
        [string] $PoolId
    )

    begin {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)

        # Load helper
        . (Join-Path -Path (Split-Path $PSScriptRoot -Parent) 'misc' 'Get-ConfigValue.ps1')
        . (Join-Path -Path (Split-Path $PSScriptRoot -Parent) 'misc' 'Invoke-RESTCommand.ps1')
    }

    process {
        $body = @{
            name = $PoolName
            pool = @{
                id = $PoolId
            }
        }

        $restInfo = Get-ConfigValue -token 'RESTElasticPoolRegisteredInProjectCreate'
        $restInputObject = @{
            method = $restInfo.method
            uri    = '"{0}"' -f ($restInfo.uri -f [uri]::EscapeDataString($Organization), [uri]::EscapeDataString($Project))
            body   = ConvertTo-Json $body -Depth 10 -Compress
        }
        $response = Invoke-RESTCommand @restInputObject

        if (-not [String]::IsNullOrEmpty($response.errorCode)) {
            Write-Error ('Failed to register pools because of [{0} - {1}]' -f $response.typeKey, $response.message)
            return
        }

        return $response.value
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
