<#
.SYNOPSIS
Fetch the latest build status for the provided image template

.DESCRIPTION
Fetch the latest build status for the provided image template

.PARAMETER TemplateFilePath
Required. The template file to fetch deployment information from (e.g. the used Resource Group name)

.PARAMETER ImageTemplateName
Required. The name of the image template to query to build status for. E.g. 'lin_it-2022-02-20-16-17-38'

.EXAMPLE
Wait-ForImageBuild -TemplateFilePath 'C:\dev\DevOps-Self-Hosted\constructs\azureImageBuilder\deploymentFiles\imageTemplate.bicep' -ImageTemplateName 'lin_it-2022-02-20-16-17-38'

Check the current build status of image template 'lin_it-2022-02-20-16-17-38' that was deployed into the Resource Group specified in the template 'imageTemplate.bicep'
#>
function Wait-ForImageBuild {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TemplateFilePath,

        [Parameter(Mandatory)]
        [string] $ImageTemplateName
    )

    begin {
        Write-Debug ('[{0} entered]' -f $MyInvocation.MyCommand)

        # Load helper
        $repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.Parent.FullName

        . (Join-Path -Path $PSScriptRoot 'Get-ImageTemplateStatus.ps1')
        . (Join-Path -Path $repoRoot 'sharedScripts' 'template' 'Get-TemplateParameterValue.ps1')
    }

    process {
        # Fetch information
        # -----------------
        $templateParamInputObject = @{
            TemplateFilePath = $TemplateFilePath
            ParameterName    = @('resourceGroupName')
        }
        $resourceGroupName = Get-TemplateParameterValue @templateParamInputObject

        # Logic
        # -----
        $currentRetry = 1
        $maximumRetries = 720
        $timeToWait = 15
        $maxTimeCalc = '{0:hh\:mm\:ss}' -f [timespan]::fromseconds($maximumRetries * $timeToWait)

        do {
            $latestStatus = Get-ImageTemplateStatus -templateResourceGroup $resourceGroupName -templateName $ImageTemplateName

            if ($latestStatus -eq 'failed' -or $latestStatus.runState.ToLower() -eq 'failed') {
                throw "Image Template [$ImageTemplateName] build failed with status [failed]"
            }

            if ($latestStatus.runState.ToLower() -notIn @('running', 'new')) {
                break
            }

            $currTimeCalc = '{0:hh\:mm\:ss}' -f [timespan]::fromseconds($currentRetry * $timeToWait)

            Write-Verbose ('[{0}] Waiting 15 seconds [{1}|{2}]' -f (Get-Date -Format 'HH:mm:ss'), $currTimeCalc, $maxTimeCalc) -Verbose
            $currentRetry++
            Start-Sleep $timeToWait
        } while ($currentRetry -le $maximumRetries)

        if ($latestStatus) {
            $duration = New-TimeSpan -Start $latestStatus.startTime -End $latestStatus.endTime
            Write-Verbose ('It took [{0}] minutes and [{1}] seconds to build and distribute the image.' -f $duration.Minutes, $duration.Seconds) -Verbose
        } else {
            Write-Warning "Timeout at [$currTimeCalc]. Note, the Azure Image Builder may still succeed."
        }
        return $latestStatus
    }

    end {
        Write-Debug ('[{0} existed]' -f $MyInvocation.MyCommand)
    }
}
