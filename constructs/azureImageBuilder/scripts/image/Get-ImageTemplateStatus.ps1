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
Get-ImageTemplateStatus -templateResourceGroup 'agent-pool-rg' -templateName 'aibIt-2023-02-01-14-24-34'

Get the status of Image Template 'aibIt-2023-02-01-14-24-34'. Returns an object such as

@{
  startTime = "2023-02-01T14:26:51.477558858Z"
  endTime   = "2023-02-01T14:55:27.021969106Z"
  runState  = "Succeeded"
  message   = ""
}
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

    $response = ((Invoke-AzRestMethod @requestInputObject).Content | ConvertFrom-Json).properties
    if ($response.lastRunStatus) {
        return $response.lastRunStatus
    } else {
        Write-Verbose ('Image Build failed with error: [{0}]' -f $response.provisioningError.message)
        return 'failed'
    }
}
