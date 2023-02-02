<#
.SYNOPSIS
Remove a deployment script matching the given prefix in the given resource group

.DESCRIPTION
Remove a deployment script matching the given prefix in the given resource group

.PARAMETER TemplateFilePath
Required. The path to the Template File to fetch the Deplyoment Script information from that are used to identify and remove the correct Deplyoment Scripts.

.EXAMPLE
Remove-DeploymentScript -TemplateFilePath 'C:\dev\DevOps-Self-Hosted\constructs\azureImageBuilder\deploymentFiles\imageTemplate.bicep'

Search and remove the deployment script specified in the deployment file 'imageTemplate.bicep
#>
function Remove-DeploymentScript {

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $TemplateFilePath
    )

    begin {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)
    }

    process {

        # Fetch information
        # -----------------
        $templateContent = az bicep build --file $templateFilePath --stdout | ConvertFrom-Json -AsHashtable

        # Get Deployment Script prefix name
        if ($templateContent.resources[-1].properties.parameters.Keys -contains 'deploymentScriptName') {
            # Used explicit value
            $deploymentScriptName = $templateContent.resources[-1].properties.parameters['deploymentScriptName'].value
        } else {
            # Used default value
            $deploymentScriptName = $templateContent.resources[-1].properties.template.parameters['deploymentScriptName'].defaultValue
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
        $fetchUri = "https://management.azure.com/subscriptions/{0}/resources?api-version=2021-04-01&`$expand=provisioningState&`$filter=resourceGroup EQ '{1}' and resourceType EQ 'Microsoft.Resources/deploymentScripts' and substringof(name, '{2}')" -f (Get-AzContext).Subscription.Id, $resourcegroupName, $deploymentScriptName
        [array] $deploymentScripts = ((Invoke-AzRestMethod -Method 'GET' -Uri $fetchUri).Content | ConvertFrom-Json).Value

        $deploymentScriptsToRemove = $deploymentScripts | Where-Object { $_.ProvisioningState -ne 'Running' }

        foreach ($deploymentScript in $deploymentScriptsToRemove) {
            if ($PSCmdlet.ShouldProcess('Deplyoment Script [{0}]' -f $deploymentScript.name, 'Remove')) {
                $res = Invoke-AzRestMethod -Method 'DELETE' -Uri ('https://management.azure.com{0}?api-version=2020-10-01' -f $deploymentScript.id)
                if ($res.StatusCode -like '2*') {
                    Write-Verbose ('Removed Deplyoment Script [{0}]' -f $deploymentScript.id) -Verbose
                } else {
                    $restError = ($res.content | ConvertFrom-Json).error
                    throw ('The removal of Deplyoment Script [{0}] failed with error code [{1}] and message [2}]' -f $deploymentScript.name, $restError.code, $restError.message)
                }
            }
        }
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
