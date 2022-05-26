<#
.SYNOPSIS
Get the instance of the given agent pool that is registered in the given project

.DESCRIPTION
Get the instance of the given agent pool that is registered in the given project

.PARAMETER Organization
Mandatory. The organization that contains the project to search in

.PARAMETER Project
Mandatory. The project to search in

.PARAMETER PoolId
Mandatory. The pool to search for

.EXAMPLE
Get-ElasticPoolRegisteredInProject -Organization 'contoso' -Project 'myProject' -PoolId 16

Get the instance of the agent pool with ID 16 that is registered in project [contoso|myProject]
#>
function Get-ElasticPoolRegisteredInProject {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Organization,

        [Parameter(Mandatory = $true)]
        [string] $Project,

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
        $restInfo = Get-ConfigValue -token 'RESTElasticPoolRegisteredInProjectGet'
        $restInputObject = @{
            method = $restInfo.method
            uri    = '"{0}"' -f ($restInfo.uri -f [uri]::EscapeDataString($Organization), [uri]::EscapeDataString($Project), $PoolId)
        }
        $response = Invoke-RESTCommand @restInputObject

        if (-not [String]::IsNullOrEmpty($response.errorCode)) {
            Write-Error ('Failed to fetch scale set pools because of [{0} - {1}]' -f $response.typeKey, $response.message)
            return
        }

        return $response.value
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
