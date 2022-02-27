<#
.SYNOPSIS
Evaluate the provided image reference and optionally select the latest version of a provided custom image reference

.DESCRIPTION
Evaluate the provided image reference and optionally select the latest version of a provided custom image reference. 
- If the image reference is not custom (i.e. is a resource ID), no changes are applied.
- If the image reference is custom and has a version provided, no changes are applied
- If the image reference is custom and no image version was provided as part of the resource ID, the latest image version is fetched and applied

.PARAMETER imageReference
Mandatory. The image reference to process

.EXAMPLE
Select-Image -imageReference @{ id = '(...)/version' }

Fetch the latest image version from the Azure Compute Gallery provided via the resource ID

.EXAMPLE
Select-Image -imageReference @{ id = '(...)/version/0.222.111' }

Pass the provided image reference thru

.EXAMPLE
Select-Image -imageReference @{ sku = '...'; provide = '...' }

Pass the provided image reference thru
#>
function Select-Image {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable] $imageReference
    )

    if ($imageReference.ContainsKey('id') -and $imageReference.id.Split('/')[-1] -eq 'latest') {
        Write-Verbose ("Fetching latest image version for image [{0}]" -f $imageReference.id.Split('/')[10])

        $imageParam = $imageReference.id.Split('/')
        $galleryResourceGroupName = $imageParam[4]
        $galleryName = $imageParam[8]
        $imageName = $imageParam[10]

        if (-not ($availableVersions = Get-AzGalleryImageVersion -ResourceGroupName $galleryResourceGroupName -GalleryName $galleryName -GalleryImageDefinitionName $imageName)) {
            throw "Now image versions found for image [$customImageDefinitionName] in gallery [$customImageGalleryName]"
        }
        $customLatestImage = (($availableVersions.Name -as [Version[]]) | Measure-Object -Maximum).Maximum.ToString()
        Write-Verbose "Latest version found is : [$customLatestImage]"

        return "{0}/{1}" -f ($imageParam[0..($imageParam.count-2)] -join '/'), $customLatestImage
    }
    else {
        Write-Verbose ("Using specified image [{0}]" -f ($imageReference | ConvertTo-Json))
    }
}