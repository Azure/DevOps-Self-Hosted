<#
.SYNOPSIS
Remove image templates that are stuck in limbo because their User-Assigned Managed Identity was deleted before the image template was deleted.

.DESCRIPTION
Remove image templates that are stuck in limbo because their User-Assigned Managed Identity was deleted before the image template was deleted.
Requires an alternative User-Assigned Identity to temporarily be assigned to the image template, so that it can be deleted.

.PARAMETER UserAssignedIdentityName
Optional. The name of the User-Assigned Identity that will be temporarily assigned to the image template. Defaults to the solution's default value.

.PARAMETER ImageTemplateResourceGroupName
Optional. The resource group to search for image templates in. Defaults to the solution's default value.

.EXAMPLE
Remove-StaleImageTemplate

Remove any image template in the solutions default resource group

.NOTES
The Azure CLI commands in this script will log error messages of the image template during execution (e.g., idenitity required / not authorized). This is expected and can be ignored.
#>
function Remove-StaleImageTemplate {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string] $UserAssignedIdentityName = 'msi-aib',

        [Parameter(Mandatory = $false)]
        [string] $ImageTemplateResourceGroupName = 'rg-ado-agents'
    )

    if ($userAssignedIdentity = Get-AzResource -ResourceGroupName $ImageTemplateResourceGroupName -ResourceName $UserAssignedIdentityName -ResourceType 'Microsoft.ManagedIdentity/userAssignedIdentities') {
        $userAssignedIdentityResourceId = $userAssignedIdentity.ResourceId
    } else {
        throw "User-Assigned Identity [$UserAssignedIdentityName] not found in resource group [$ImageTemplateResourceGroupName]. Make sure you create it before running this script."
    }

    $templates = $(az image builder list --query "[?resourceGroup == '$ImageTemplateResourceGroupName'].name" --output tsv)

    $templates | ForEach-Object -ThrottleLimit 5 -Parallel {
        Write-Output "Processing $_"
        az image builder identity remove --resource-group $using:ImageTemplateResourceGroupName -n $_ --user-assigned -y
        az image builder delete -g $using:ImageTemplateResourceGroupName -n $_ 2>nul
        az image builder identity assign -g $using:ImageTemplateResourceGroupName -n $_ --user-assigned $using:userAssignedIdentityResourceId
        az image builder delete -g $using:ImageTemplateResourceGroupName -n $_ --only-show-errors
    }
}
