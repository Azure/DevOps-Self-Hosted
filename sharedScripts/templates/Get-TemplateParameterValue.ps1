function Get-TemplateParameterValue {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $TemplateFilePath,

        [Parameter(Mandatory = $true)]
        [string] $ParameterName
    )

    $templateContent = az bicep build --file $TemplateFilePath --stdout | ConvertFrom-Json -AsHashtable

    # Get Storage Account name
    if ($templateContent.resources[-1].properties.parameters.Keys -contains $ParameterName) {
        # Used explicit value
        return $templateContent.resources[-1].properties.parameters[$ParameterName].value
    } else {
        # Used default value
        return $templateContent.resources[-1].properties.template.parameters[$ParameterName].defaultValue
    }
}
