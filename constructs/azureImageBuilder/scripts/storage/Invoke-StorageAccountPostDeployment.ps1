<#
.SYNOPSIS
Run the Post-Deployment for the storage account deployment

.DESCRIPTION
Run the Post-Deployment for the storage account deployment
- Upload required data to the storage account

.PARAMETER TemplateFilePath
Required. The template file to fetch deployment information from (e.g. the used Storage Account name)

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
Invoke-StorageAccountPostDeployment -TemplateFilePath 'C:\dev\DevOps-Self-Hosted\constructs\azureImageBuilder\deploymentFiles\sbx.imageTemplate.bicep'

Upload any required data to the storage account specified in the template file 'sbx.imageTemplate.bicep' to the default containers.
#>
function Invoke-StorageAccountPostDeployment {

    [CmdletBinding(SupportsShouldProcess = $True)]
    param(
        [Parameter(Mandatory = $true)]
        [string] $TemplateFilePath,

        [Parameter(Mandatory = $false)]
        [Hashtable[]] $ContentToUpload = $(
            @{
                sourcePath      = 'windows'
                targetContainer = 'aibscripts'
            },
            @{
                sourcePath      = 'linux'
                targetContainer = 'aibscripts'
            }
        )
    )

    $templateContent = az bicep build --file $TemplateFilePath --stdout | ConvertFrom-Json -AsHashtable

    # Get Storage Account name
    if ($templateContent.resources[-1].properties.parameters.Keys -contains 'storageAccountName') {
        # Used explicit value
        $storageAccountName = $templateContent.resources[-1].properties.parameters['storageAccountName'].value
    } else {
        # Used default value
        $storageAccountName = $templateContent.resources[-1].properties.template.parameters['storageAccountName'].defaultValue
    }


    Write-Verbose 'Getting storage account context.'
    $saResource = Get-AzResource -Name $storageAccountName -ResourceType 'Microsoft.Storage/storageAccounts'

    $storageAccount = Get-AzStorageAccount -ResourceGroupName $saResource.ResourceGroupName -StorageAccountName $storageAccountName -ErrorAction Stop
    $ctx = $storageAccount.Context

    Write-Verbose 'Building paths to the local folders to upload.'
    Write-Verbose "Script Directory: '$PSScriptRoot'"
    $contentDirectory = Join-Path -Path (Split-Path $PSScriptRoot -Parent) 'Uploads'
    Write-Verbose "Content directory: '$contentDirectory'"

    foreach ($contentObject in $contentToUpload) {

        $sourcePath = $contentObject.sourcePath
        $targetContainer = $contentObject.targetContainer

        try {
            $pathToContentToUpload = Join-Path $contentDirectory $sourcePath
            Write-Verbose "Processing content in path: '$pathToContentToUpload'"

            Write-Verbose 'Testing local path'
            If (-Not (Test-Path -Path $pathToContentToUpload)) {
                throw "Testing local paths FAILED: Cannot find content path to upload '$pathToContentToUpload'"
            }
            Write-Verbose 'Testing paths: SUCCEEDED'

            Write-Verbose 'Getting files to be uploaded...'
            $scriptsToUpload = Get-ChildItem -Path $pathToContentToUpload -ErrorAction Stop
            Write-Verbose 'Files to be uploaded:'
            $scriptsToUpload.Name | ForEach-Object { Write-Verbose "- $_" }

            Write-Verbose 'Testing blob container'
            Get-AzStorageContainer -Name $targetContainer -Context $ctx -ErrorAction Stop
            Write-Verbose 'Testing blob container SUCCEEDED'

            if ($PSCmdlet.ShouldProcess("Files to the '$targetContainer' container", 'Upload')) {
                $scriptsToUpload | Set-AzStorageBlobContent -Container $targetContainer -Context $ctx -Force -ErrorAction 'Stop' | Out-Null
            }
        } catch {
            Write-Error "Upload FAILED: $_"
        }
    }
}
