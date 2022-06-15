<#
.SYNOPSIS
Remove a deployment script matching the given prefix in the given resource group

.DESCRIPTION
Remove a deployment script matching the given prefix in the given resource group

.PARAMETER ResourceGroupName
Required. The resource group name the deployment script is deployed into

.PARAMETER DeploymentScriptPrefix
Optional. The prefix of the deployment script to remove.

.EXAMPLE
Remove-DeploymentScript -ResourceGroupName 'My-RG' -DeploymentScriptPrefix 'triggerBuild-imageTemplate-'

Search and remove the deployment script with prefix 'triggerBuild-imageTemplate-' and its generated resource group 'My-RG'
#>
function Remove-DeploymentScript {

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $false)]
        [string] $DeploymentScriptPrefix = 'triggerBuild-imageTemplate-'
    )

    $deploymentScripts = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.Resources/deploymentScripts'

    $deploymentScriptsToRemove = $deploymentScripts | Where-Object { $_.Name -like "$DeploymentScriptPrefix*" }

    $deploymentScriptsToRemove | ForEach-Object -ThrottleLimit 5 -Parallel {
        $null = Remove-AzResource -ResourceId $_.ResourceId -Force
        Write-Verbose ('Removed Deployment Script with resource ID [{0}]' -f $_.ResourceId) -Verbose
    }
}
