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

    begin {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)
    }

    process {
        $fetchUri = "https://management.azure.com/subscriptions/{0}/resources?api-version=2021-04-01&`$expand=provisioningState&`$filter=resourceGroup EQ '{1}' and resourceType EQ 'Microsoft.Resources/deploymentScripts' and substringof(name, '{2}')" -f (Get-AzContext).Subscription.Id, $resourcegroupName, $DeploymentScriptPrefix
        [array] $deploymentScripts = ((Invoke-AzRestMethod -Method 'GET' -Uri $fetchUri).Content | ConvertFrom-Json).Value

        $deploymentScriptsToRemove = $deploymentScripts | Where-Object { $_.ProvisioningState -ne 'Running' }

        $deploymentScriptsToRemove | ForEach-Object -ThrottleLimit 5 -Parallel {
            $null = Invoke-AzRestMethod -Method 'DELETE' -Uri ('https://management.azure.com/{0}?api-version=2021-04-01' -f $_.Id)
            Write-Verbose ('Removed Deployment Script with resource ID [{0}]' -f $_.Id) -Verbose
        }
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
