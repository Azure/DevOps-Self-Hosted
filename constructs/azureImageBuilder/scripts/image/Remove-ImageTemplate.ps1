<#
.SYNOPSIS
Remove the image templates and their temporary generated resource groups

.DESCRIPTION
Remove the image templates and their temporary generated resource groups

.PARAMETER resourcegroupName
Required. The resource group name the image template is deployed into

.PARAMETER imageTemplateName
Optional. The name of the image template. Defaults to '*'.

.PARAMETER Confirm
Request the user to confirm whether to actually execute any should process

.PARAMETER WhatIf
Perform a dry run of the script. Runs everything but the content of any should process

.EXAMPLE
Remove-ImageTemplate -resourcegroupName 'WVD-Imaging-TO-RG'

Search and remove the image template '*' and its generated resource group 'IT_WVD-Imaging-TO-RG_*'

.EXAMPLE
Remove-ImageTemplate -resourcegroupName 'WVD-Imaging-TO-RG' -imageTemplateName '19h2NoOffice'

Search and remove the image template '19h2NoOffice' and its generated resource group 'IT_WVD-Imaging-TO-RG_19h2NoOffice*'
#>
function Remove-ImageTemplate {

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string] $resourcegroupName,

        [Parameter(Mandatory = $false)]
        [string] $imageTemplateName = ''
    )

    begin {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)

        # Install required modules
        $currentVerbosePreference = $VerbosePreference
        $VerbosePreference = 'SilentlyContinue'
        $requiredModules = @(
            'Az.Resources',
            'Az.ResourceGraph'
        )
        foreach ($moduleName in $requiredModules) {
            if (-not ($installedModule = Get-Module $moduleName -ListAvailable)) {
                Install-Module $moduleName -Repository 'PSGallery' -Force -Scope 'CurrentUser'
                if ($installed = Get-Module -Name $moduleName -ListAvailable) {
                    Write-Verbose ('Installed module [{0}] with version [{1}]' -f $installed.Name, $installed.Version) -Verbose
                }
            } else {
                Write-Verbose ('Module [{0}] already installed in version [{1}]' -f $installedModule.Name, $installedModule.Version) -Verbose
            }
        }
        $VerbosePreference = $currentVerbosePreference

        # Load helper
        . (Join-Path -Path $PSScriptRoot 'Get-ImageTemplateStatus.ps1')
    }

    process {
        [array] $imageTemplateResources = (Search-AzGraph -Query "Resources | where resourceGroup == '$resourcegroupName' | where name startswith '$imageTemplateName'")
        [array] $filteredTemplateResource = $imageTemplateResources | Where-Object { (Get-ImageTemplateStatus -templateResourceGroup $_.ResourceGroup -templateName $_.name) -notIn @('running', 'new') }
        Write-Verbose ('Found [{0}] image templates to remove.' -f $filteredTemplateResource.Count)
        if ($imageTemplateResources.Count -gt $filteredTemplateResource.Count) {
            Write-Verbose ("[{0}] instances are filtered as they are still in state 'running'." -f ($imageTemplateResources.Count - $filteredTemplateResource.Count))
        }

        foreach ($imageTemplateResource in $filteredTemplateResource) {
            if ($PSCmdlet.ShouldProcess('Image template [{0}]' -f $imageTemplateResource.Name, 'Remove')) {
                $null = Remove-AzResource -ResourceId $imageTemplateResource.id -Force
                Write-Verbose ('Remove image template [{0}]' -f $imageTemplateResource.id) -Verbose
            }
        }
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
