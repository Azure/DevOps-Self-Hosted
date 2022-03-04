<#
.SYNOPSIS
Get the config object matching the given token

.DESCRIPTION
Get the config object matching the given token from the REST.json file

.PARAMETER token
Parameter description

.EXAMPLE
Get-ConfigValue -token 'myToken'

Returns the value matching the 'myToken' name
#>
function Get-ConfigValue {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $token
    )

    begin {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)
    }

    process {
        $content = Get-Content (Join-Path $PSScriptRoot 'REST.json') -Raw | Out-String
        $converted = ConvertFrom-Json $content
        return  $converted.$token
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
