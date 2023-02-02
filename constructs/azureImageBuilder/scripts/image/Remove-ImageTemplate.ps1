<#
.SYNOPSIS
Remove the Image Templates and their temporary generated resource groups

.DESCRIPTION
Remove the Image Templates and their temporary generated resource groups

.PARAMETER TemplateFilePath
Required. The path to the Template File to fetch the Image Template information from that are used to identify and remove the correct Image Templates.

.EXAMPLE
Remove-ImageTemplate -TemplateFilePath 'C:\dev\DevOps-Self-Hosted\constructs\azureImageBuilder\deploymentFiles\imageTemplate.bicep'

Search and remove the Image Template specified in the deployment file 'imageTemplate.bicep
#>
function Remove-ImageTemplate {

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string] $TemplateFilePath
    )

    begin {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)

        # Load helper
        . (Join-Path -Path $PSScriptRoot 'Get-ImageTemplateStatus.ps1')
    }

    process {
        # Fetch information
        # -----------------
        $templateContent = az bicep build --file $TemplateFilePath --stdout | ConvertFrom-Json -AsHashtable

        # Get Image Template name
        if ($templateContent.resources[-1].properties.parameters.Keys -contains 'imageTemplateName') {
            # Used explicit value
            $imageTemplateName = $templateContent.resources[-1].properties.parameters['imageTemplateName'].value
        } else {
            # Used default value
            $imageTemplateName = $templateContent.resources[-1].properties.template.parameters['imageTemplateName'].defaultValue
        }

        # Get Resource Group name
        if ($templateContent.resources[-1].properties.parameters.Keys -contains 'resourceGroupName') {
            # Used explicit value
            $resourceGroupName = $templateContent.resources[-1].properties.parameters['resourceGroupName'].value
        } else {
            # Used default value
            $resourceGroupName = $templateContent.resources[-1].properties.template.parameters['resourceGroupName'].defaultValue
        }

        # Logic
        # -----
        $fetchUri = "https://management.azure.com/subscriptions/{0}/resources?api-version=2021-04-01&`$expand=provisioningState&`$filter=resourceGroup EQ '{1}' and resourceType EQ 'Microsoft.VirtualMachineImages/imageTemplates' and substringof(name, '{2}')" -f (Get-AzContext).Subscription.Id, $resourcegroupName, $imageTemplateName
        [array] $imageTemplateResources = ((Invoke-AzRestMethod -Method 'GET' -Uri $fetchUri).Content | ConvertFrom-Json).Value
        [array] $filteredTemplateResource = $imageTemplateResources | Where-Object { (Get-ImageTemplateStatus -TemplateResourceGroup $resourcegroupName -TemplateName $_.name).runState -notIn @('running', 'new') }

        Write-Verbose ('Found [{0}] Image Templates to remove.' -f $filteredTemplateResource.Count)
        if ($imageTemplateResources.Count -gt $filteredTemplateResource.Count) {
            Write-Verbose ("[{0}] instances are filtered as they are still in state 'running'." -f ($imageTemplateResources.Count - $filteredTemplateResource.Count))
        }

        foreach ($imageTemplateResource in $filteredTemplateResource) {
            if ($PSCmdlet.ShouldProcess('Image Template [{0}]' -f $imageTemplateResource.name, 'Remove')) {
                $res = Invoke-AzRestMethod -Method 'DELETE' -Uri ('https://management.azure.com{0}?api-version=2022-02-14' -f $imageTemplateResource.id)
                if ($res.StatusCode -like '2*') {
                    Write-Verbose ('Removed Image Template [{0}]' -f $imageTemplateResource.id) -Verbose
                } else {
                    $restError = ($res.content | ConvertFrom-Json).error
                    throw ('The removal of Image Template [{0}] failed with error code [{1}] and message [2}]' -f $_.name, $restError.code, $restError.message)
                }
            }
        }
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
