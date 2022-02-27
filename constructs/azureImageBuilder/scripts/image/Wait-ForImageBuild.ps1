<#
.SYNOPSIS
Fetch the latest build status for the provided image template

.DESCRIPTION
Fetch the latest build status for the provided image template

.PARAMETER ResourceGroupName
Required. The resource group the image template was deployed into.

.PARAMETER ImageTemplateName
Required. The name of the image template to query to build status for. E.g. 'lin_it-2022-02-20-16-17-38'

.EXAMPLE
Wait-ForImageBuild -ResourceGroupName 'agents-vmss-rg' -ImageTemplateName 'lin_it-2022-02-20-16-17-38'  

Check the current build status of image template 'lin_it-2022-02-20-16-17-38' that was deployed into resource group 'agents-vmss-rg'
#>
function Wait-ForImageBuild {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory)]
        [string] $ImageTemplateName
    )

    begin {
        Write-Debug ("[{0} entered]" -f $MyInvocation.MyCommand)

        # Load helper
        . (Join-Path $PSScriptRoot 'Get-ImageTemplateStatus.ps1')
    }

    process {
        $currentRetry = 1
        $maximumRetries = 720
        $timeToWait = 15
        $maxTimeCalc = "{0:hh\:mm\:ss}" -f [timespan]::fromseconds($maximumRetries*$timeToWait)

        do {
            $latestStatus = Get-ImageTemplateStatus -templateResourceGroup $ResourceGroupName -templateName $ImageTemplateName
            if ($latestStatus -notIn @('running', 'new')) {

                if ($latestStatus -eq 'failed') {
                    throw $latestStatus
                }
                break
            }

            $currTimeCalc = "{0:hh\:mm\:ss}" -f [timespan]::fromseconds($currentRetry*$timeToWait)

            Write-Verbose ("[{0}] Waiting 15 seconds [{1}|{2}]" -f (Get-Date -Format 'HH:mm:ss'), $currTimeCalc, $maxTimeCalc) -Verbose
            $currentRetry++
            Start-Sleep $timeToWait
        } while ($currentRetry -le $maximumRetries)

        $Duration = New-TimeSpan -Start $latestStatus.startTime -End $latestStatus.endTime

        Write-Verbose "It took $($Duration.TotalMinutes) minutes to build and distribute the image." -Verbose
        return $latestStatus
    }

    end {
        Write-Debug ("[{0} existed]" -f $MyInvocation.MyCommand)
    }
}