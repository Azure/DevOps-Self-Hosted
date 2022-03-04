<#
.SYNOPSIS
Get the current status of an image template built

.DESCRIPTION
Get the current status of an image template built

.PARAMETER templateResourceGroup
Required. The resource group the image template was deployed into

.PARAMETER templateName
Required. The name of the image template

.EXAMPLE
Get-ImageTemplateStatus -templateResourceGroup 'agent-vmss-rg' -templateName ''

#>
function Get-ImageTemplateStatus {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $templateResourceGroup,

        [Parameter(Mandatory = $true)]
        [string] $templateName
    )

    $context = Get-AzContext
    $subscriptionId = $context.Subscription.Id

    $path = '/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.VirtualMachineImages/imageTemplates/{2}?api-version=2020-02-14' -f $subscriptionId, $templateResourceGroup, $templateName
    $requestInputObject = @{
        Method = 'GET'
        Path   = $path
    }
    return ((Invoke-AzRestMethod @requestInputObject).Content | ConvertFrom-Json).properties.lastRunStatus.runState.ToLower()
}
