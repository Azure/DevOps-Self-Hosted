<#
.SYNOPSIS
Remove either the resources in the Image Template Resource Group or the whole Resource Group

.DESCRIPTION
Remove either the resources in the Image Template Resource Group or the whole Resource Group

.PARAMETER TemplateFilePath
Required. The path to the Template File to fetch the Image Tempalte information from that are used to identify and remove the correct Resource Group (resources).

.PARAMETER RemoveImageTemplateResourceGroup
Optional. A switch to control whether to just remove the resources in the Image Template Staging Resource Group or the whole Resource Group.
Keeping the Resource Group may be relevant if one deployed an exception for this resource group to allow the Image Builder to create a storage account with a public endpoint even though a policy may require it to be disabled.

.EXAMPLE
Remove-ResourcesInStagingRg -TemplateFilePath 'C:\dev\DevOps-Self-Hosted\constructs\azureImageBuilder\deploymentFiles\imageTemplate.bicep'

Removes the resources in the Image Template Staging Resource Group, if any.
#>
function Remove-ResourcesInStagingRg {

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $TemplateFilePath,

        [Parameter(Mandatory = $false)]
        [switch] $RemoveImageTemplateResourceGroup
    )

    # Fetch information
    # -----------------
    $templateParamInputObject = @{
        TemplateFilePath = $TemplateFilePath
        ParameterName    = @('imageTemplateResourceGroupName')
    }
    $imageTemplateResourceGroupName = Get-TemplateParameterValue @templateParamInputObject


    if (-not (Get-AzResourceGroup $imageTemplateResourceGroupName -ErrorAction SilentlyContinue)) {
        Write-Verbose ('Resource Group [{0}] does not exist. Skipping cleanup.' -f $imageTemplateResourceGroupName) -Verbose
        return
    }

    # Fetching & removing resources
    # =============================
    if ($RemoveImageTemplateResourceGroup) {
        Write-Verbose "Removing resource group [$imageTemplateResourceGroupName]"
        if ($PSCmdlet.ShouldProcess('Resource [{0}]' -f $resource.Id, 'Remove')) {
            $null = Remove-AzResourceGroup -Name $imageTemplateResourceGroupName -Force -ErrorAction 'SilentlyContinue'
        }
        return
    }


    $imageTemplateResources = Get-AzResource -ResourceGroupName $imageTemplateResourceGroupName

    if ($imageTemplateResources.Count -gt 0) {

        Write-Verbose 'Removing resources:'
        foreach ($resource in $imageTemplateResources) {
            Write-Verbose ('- [{0}]' -f $resource.id)
        }

        foreach ($resource in $imageTemplateResources) {
            if ($PSCmdlet.ShouldProcess('Resource [{0}]' -f $resource.Id, 'Remove')) {
                $null = Remove-AzResource -ResourceId $resource.Id -Force -ErrorAction 'Stop'
            }
        }
    }
}
