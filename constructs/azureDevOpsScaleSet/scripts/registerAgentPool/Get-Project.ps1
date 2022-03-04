<#
.SYNOPSIS
Find a Azure DevOps project in the given organization

.DESCRIPTION
Find a Azure DevOps project in the given organization

.PARAMETER Organization
Mandatory. The organization that contains the project

.PARAMETER Project
Mandatory. The project to search for inside the organization

.EXAMPLE
Get-Project -Organization 'contoso' -Project 'myProject'

Search for project 'myProject' in organization 'contoso'
#>
function Get-Project {

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
        $restInfo = Get-ConfigValue -token 'RESTProjectGet'
        $restInputObject = @{
            method = $restInfo.method
            uri    = '"{0}"' -f ($restInfo.uri -f [uri]::EscapeDataString($Organization), [uri]::EscapeDataString($Project))
        }
        $response = Invoke-RESTCommand @restInputObject

        return $response
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
