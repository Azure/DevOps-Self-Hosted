<#
.SYNOPSIS
Get a list of all elastic pools (scale set agent pools) in the given project

.DESCRIPTION
Get a list of all elastic pools (scale set agent pools) in the given project

.PARAMETER Organization
Mandatory. The organization that contains the project to search in

.PARAMETER Project
Mandatory. The project to search in

.EXAMPLE
Get-ElasticPool -Organization 'contoso' -Project 'myProject'

Get all elastic pools registered in project [contoso|myProject]
#>
function Get-ElasticPool {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Organization,

        [Parameter(Mandatory = $true)]
        [string] $Project
    )

    begin {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)

        # Load helper
        . (Join-Path (Split-Path $PSScriptRoot -Parent) 'misc' 'Get-ConfigValue.ps1')
        . (Join-Path (Split-Path $PSScriptRoot -Parent) 'misc' 'Invoke-RESTCommand.ps1')
    }

    process {
        $restInfo = Get-ConfigValue -token 'RESTElasticPoolList'
        $restInputObject = @{
            method = $restInfo.method
            uri    = '"{0}"' -f ($restInfo.uri -f [uri]::EscapeDataString($Organization), [uri]::EscapeDataString($Project))
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
