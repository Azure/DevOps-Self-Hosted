<#
.SYNOPSIS
Run the Post-Deployment for the storage account deployment

.DESCRIPTION
Run the Post-Deployment for the storage account deployment
- Upload required data to the storage account

.PARAMETER StorageAccountName
Required. The name of the Storage Account to upload to

.PARAMETER ContentToUpload
Required. The map of source paths & target container tuples. For example:
$(
    @{
        sourcePath = 'windows'
        targetContainer = 'aibscripts'
    },
    @{
        sourcePath = 'linux'
        targetContainer = 'aibscripts'
    }
)

.EXAMPLE
Invoke-StorageAccountPostDeployment -StorageAccountName 'mystorage'

Upload any required data to the storage account 'mystorage' to the default containers.
#>

[CmdletBinding(SupportsShouldProcess = $True)]
param(
    [Parameter(Mandatory = $true)]
    [string] $StorageAccountName,

    [Parameter(Mandatory = $true)]
    [string] $TargetContainer
)

Write-Verbose 'Fetching & storing scripts' -Verbose
$contentDirectoryName = 'scripts'
$contentDirectory = (New-Item $contentDirectoryName -ItemType 'Directory' -Force).FullName
$scriptPaths = @()
foreach ($scriptEnvVar in (Get-ChildItem 'env:*').Name | Where-Object { $_ -like 'script_*' }) {
    # Handle value like 'script_Windows_Install_ps1
    $scriptExtension = Split-Path ($scriptEnvVar -replace '_', '.') -Extension
    $scriptNameSuffix = ($scriptExtension -split '\.')[1]
    $scriptName = '{0}{1}' -f (($scriptEnvVar -replace 'script_', '') -replace "_$scriptNameSuffix", ''), $scriptExtension

    $scriptContent = (Get-Item env:$scriptEnvVar).Value

    Write-Verbose ('Storing file [{0}] with length [{1}]' -f $scriptName, $scriptContent.Length) -Verbose
    $scriptPaths += (New-Item (Join-Path $contentDirectoryName $scriptName) -ItemType 'File' -Value $scriptContent -Force).FullName
}

Write-Verbose 'Getting storage account context.' -Verbose
$saResource = Get-AzResource -Name $storageAccountName -ResourceType 'Microsoft.Storage/storageAccounts'

$storageAccount = Get-AzStorageAccount -ResourceGroupName $saResource.ResourceGroupName -StorageAccountName $storageAccountName -ErrorAction 'Stop'
$ctx = $storageAccount.Context

Write-Verbose 'Building paths to the local folders to upload.' -Verbose
Write-Verbose "Content directory: '$contentDirectory'" -Verbose

foreach ($scriptPath in $scriptPaths) {

    try {
        Write-Verbose 'Testing blob container' -Verbose
        Get-AzStorageContainer -Name $targetContainer -Context $ctx -ErrorAction 'Stop'
        Write-Verbose 'Testing blob container SUCCEEDED' -Verbose

        Write-Verbose ('Uploading file [{0}] to container [{1}]' -f (Split-Path $scriptPath -Leaf), $TargetContainer) -Verbose
        if ($PSCmdlet.ShouldProcess(('File [{0}] to container [{1}]' -f (Split-Path $scriptPath -Leaf), $TargetContainer), 'Upload')) {
            $null = $scriptPath | Set-AzStorageBlobContent -Container $targetContainer -Context $ctx -Force -ErrorAction 'Stop'
        }
    } catch {
        Write-Error "Upload FAILED: $_"
    }
}
