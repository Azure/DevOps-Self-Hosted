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

        # Install required modules
        $currentVerbosePreference = $VerbosePreference
        $VerbosePreference = 'SilentlyContinue'
        $requiredModules = @(
            'Az.Resources'
        )
        foreach ($moduleName in $requiredModules) {
            if (-not ($installedModule = Get-Module $moduleName -ListAvailable)) {
                Install-Module $moduleName -Repository 'PSGallery' -Force -Scope 'CurrentUser'
                if ($installed = Get-Module -Name $moduleName -ListAvailable) {
                    Write-Verbose ('Installed module [{0}] with version [{1}]' -f $installed.Name, $installed.Version) -Verbose
                }
            } else {
                Write-Verbose ('Module [{0}] already installed in version [{1}]' -f $installedModule[0].Name, $installedModule[0].Version) -Verbose
            }
        }
        $VerbosePreference = $currentVerbosePreference
    }

    process {
        $deploymentScripts = Get-AzDeploymentScript -ResourceGroupName $ResourceGroupName

        $deploymentScriptsToRemove = $deploymentScripts | Where-Object { $_.Name -like "$DeploymentScriptPrefix*" -and $_.ProvisioningState -ne 'Running' }

        $deploymentScriptsToRemove | ForEach-Object -ThrottleLimit 5 -Parallel {
            $null = Remove-AzResource -ResourceId $_.Id -Force
            Write-Verbose ('Removed Deployment Script with resource ID [{0}]' -f $_.ResourceId) -Verbose
        }
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
