<#
.SYNOPSIS
Run the Post-Deployment for the storage account deployment

.DESCRIPTION
Run the Post-Deployment for the storage account deployment
- Upload required data to the storage account

.PARAMETER storageAccountName
Mandatory. Name of the storage account to host the deployment files

.PARAMETER Confirm
Will promt user to confirm the action to create invasible commands

.PARAMETER WhatIf
Dry run of the script

.EXAMPLE
Invoke-StorageAccountPostDeployment -orchestrationFunctionsPath $currentDir -storageAccountName "wvdStorageAccount"

Upload any required data to the storage account
#>
function Invoke-StorageAccountPostDeployment {

    [CmdletBinding(SupportsShouldProcess = $True)]
    param(
        [Parameter(
            Mandatory,
            HelpMessage = "Specifies the name of the Storage account to update."
        )]
        [string] $StorageAccountName,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "Map of source/target tuples for upload"
        )]
        [Hashtable[]] $contentToUpload = $(
            @{
                sourcePath = 'windows'
                targetBlob = 'aibscripts'
            },
            @{
                sourcePath = 'linux'
                targetBlob = 'aibscripts'
            }
        )
    )

    Write-Verbose "Getting storage account context."
    $saResource = Get-AzResource -Name $StorageAccountName -ResourceType 'Microsoft.Storage/storageAccounts'

    $storageAccount = Get-AzStorageAccount -ResourceGroupName $saResource.ResourceGroupName -StorageAccountName $StorageAccountName -ErrorAction Stop
    $ctx = $storageAccount.Context

    Write-Verbose "Building paths to the local folders to upload."
    Write-Verbose "Script Directory: '$PSScriptRoot'"
    $contentDirectory = Join-Path -Path (Split-Path $PSScriptRoot -Parent) "Uploads"
    Write-Verbose "Content directory: '$contentDirectory'"

    foreach ($contentObject in $contentToUpload) {

        $sourcePath = $contentObject.sourcePath
        $targetBlob = $contentObject.targetBlob

        try {
            $pathToContentToUpload = Join-Path $contentDirectory $sourcePath
            Write-Verbose "Processing content in path: '$pathToContentToUpload'"

            Write-Verbose "Testing local path"
            If (-Not (Test-Path -Path $pathToContentToUpload)) {
                throw "Testing local paths FAILED: Cannot find content path to upload '$pathToContentToUpload'"
            }
            Write-Verbose "Testing paths: SUCCEEDED"

            Write-Verbose "Getting files to be uploaded..."
            $scriptsToUpload = Get-ChildItem -Path $pathToContentToUpload -ErrorAction Stop
            Write-Verbose "Files to be uploaded:"
            Write-Verbose ($scriptsToUpload.Name | Format-List | Out-String)

            Write-Verbose "Testing blob container"
            Get-AzStorageContainer -Name $targetBlob -Context $ctx -ErrorAction Stop
            Write-Verbose "Testing blob container SUCCEEDED"

            if ($PSCmdlet.ShouldProcess("Files to the '$targetBlob' container", "Upload")) {
                $scriptsToUpload | Set-AzStorageBlobContent -Container $targetBlob -Context $ctx -Force -ErrorAction 'Stop' | Out-Null
            }
        }
        catch {
            Write-Error "Upload FAILED: $_"
        }
    }
}
