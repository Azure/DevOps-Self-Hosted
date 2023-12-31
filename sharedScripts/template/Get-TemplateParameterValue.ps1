<#
.SYNOPSIS
Fetch a specified parameter value (or default value) from the contruct's deployment template file

.DESCRIPTION
Fetch a specified parameter value (or default value) from the contruct's deployment template file
The deployment will search for the parameter's value in 2 places:
1. The parameters passed from the Deployment (/Parameter) File into the Template File
2. The Template File's default value for set parameter (if any)

The first option takes precedence over the second.

.PARAMETER TemplateFilePath
Mandatory. The path to the Deployment File to search in.

.PARAMETER ParameterName
Optional. The names of the parameter(s) to search for.

.EXAMPLE
$resourceGroupName = Get-TemplateParameterValue -TemplateFilePath 'C:\constructs\azureImageBuilder\deploymentFiles\sbx.image.bicep' -ParameterName 'resourceGroupName'

Fetch the value for the parameter 'resourceGroupName' from template 'sbx.image.bicep' and assign it to the corresponding local variable for subsequent use

.EXAMPLE
$var1, $var2 = Get-TemplateParameterValue -TemplateFilePath 'C:\constructs\azureImageBuilder\deploymentFiles\sbx.image.bicep' -ParameterName @('var1', 'var2')

Fetch the values for the parameters 'var1' & 'var2' from template 'sbx.image.bicep' and assign them to the corresponding local variables for subsequent use
#>
function Get-TemplateParameterValue {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $TemplateFilePath,

        [Parameter(Mandatory = $false)]
        [string[]] $ParameterName = @()
    )

    $templateContent = az bicep build --file $TemplateFilePath --stdout | ConvertFrom-Json -AsHashtable

    $res = @()
    # TODO: Enable to work with User-defined-types
    foreach ($name in $ParameterName) {
        # Get Storage Account name
        if ($templateContent.resources[-1].properties.parameters.Keys -contains $name) {
            # Used explicit value
            $res += $templateContent.resources[-1].properties.parameters[$name].value
        } else {
            # Used default value
            $res += $templateContent.resources[-1].properties.template.parameters[$name].defaultValue
        }
    }

    return $res
}
