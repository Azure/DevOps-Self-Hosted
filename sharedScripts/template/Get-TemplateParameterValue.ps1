function Get-TemplateParameterValue {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $TemplateFilePath,

        [Parameter(Mandatory = $true)]
        [string[]] $ParameterName
    )

    $templateContent = az bicep build --file $TemplateFilePath --stdout | ConvertFrom-Json -AsHashtable

    $res = @()

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
