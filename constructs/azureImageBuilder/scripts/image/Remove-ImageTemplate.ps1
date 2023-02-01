<#
.SYNOPSIS
Remove the image templates and their temporary generated resource groups

.DESCRIPTION
Remove the image templates and their temporary generated resource groups

.PARAMETER resourcegroupName
Required. The resource group name the image template is deployed into

.PARAMETER imageTemplateName
Required. The name of the image template.

.PARAMETER Confirm
Request the user to confirm whether to actually execute any should process

.PARAMETER WhatIf
Perform a dry run of the script. Runs everything but the content of any should process

.EXAMPLE
Remove-ImageTemplate -resourcegroupName 'My-RG' -imageTemplateName '19h2NoOffice'

Search and remove the image template '19h2NoOffice' and its generated resource group 'IT_My-RG_19h2NoOffice*'
#>
function Remove-ImageTemplate {

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string] $resourcegroupName,

        [Parameter(Mandatory = $true)]
        [string] $imageTemplateName
    )

    begin {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)

        # Load helper
        . (Join-Path -Path $PSScriptRoot 'Get-ImageTemplateStatus.ps1')
    }

    process {
        $fetchUri = "https://management.azure.com/subscriptions/{0}/resources?api-version=2021-04-01&`$expand=provisioningState&`$filter=resourceGroup EQ '{1}' and resourceType EQ 'Microsoft.VirtualMachineImages/imageTemplates' and substringof(name, '{2}')" -f (Get-AzContext).Subscription.Id, $resourcegroupName, $imageTemplateName
        [array] $imageTemplateResources = ((Invoke-AzRestMethod -Method 'GET' -Uri $fetchUri).Content | ConvertFrom-Json).Value
        [array] $filteredTemplateResource = $imageTemplateResources | Where-Object { (Get-ImageTemplateStatus -TemplateResourceGroup $resourcegroupName -TemplateName $_.name).runState -notIn @('running', 'new') }
        Write-Verbose ('Found [{0}] image templates to remove.' -f $filteredTemplateResource.Count)
        if ($imageTemplateResources.Count -gt $filteredTemplateResource.Count) {
            Write-Verbose ("[{0}] instances are filtered as they are still in state 'running'." -f ($imageTemplateResources.Count - $filteredTemplateResource.Count))
        }

        foreach ($imageTemplateResource in $filteredTemplateResource) {
            if ($PSCmdlet.ShouldProcess('Image template [{0}]' -f $imageTemplateResource.Name, 'Remove')) {
                $null = Invoke-AzRestMethod -Method 'DELETE' -Uri ('https://management.azure.com/{0}?api-version=2021-04-01' -f $imageTemplateResource.Id)
                Write-Verbose ('Removed image template [{0}]' -f $imageTemplateResource.id) -Verbose
            }
        }
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
