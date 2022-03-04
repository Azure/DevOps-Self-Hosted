<#
.SYNOPSIS
Overwrite a given paremeter.json with a version populated by the values in the provided valuemap

.DESCRIPTION
Overwrite a given paremeter.json with a version populated by the values in the provided valuemap

.PARAMETER parameterFilePath
Mandatory. Full path to the parameter file

.PARAMETER valueMap
Mandatory. Array with [Path = targetPath; Value = targetValue] or [Path = targetPath; Value = targetValue; ReplaceToken = 'myToken'] hashtables.
The Path has to start below the parameters:{} level of the parameter file
If a replace token is specified, only this value will be replaced with the targetValue
If a reploce token is NOT specified, the whole value will be replaced with the targed value

.PARAMETER jsonDepth
Optional. The depth of the json to deal with. Important for the convertion back into the json format. Defaults to 15

.EXAMPLE
Set-CustomParameter -parameterFilePath 'C:/parameter.json' -valueMap @( @{ Path = pathA;  Value = 'valueA'}, @{ Path = pathB; Value = 'valueB' })

Overwrite all parameter in the parameter.json file that match the paths 'pathA' & 'pathB' with the values 'valueA' & 'valueB' respectively

.EXAMPLE
Set-CustomParameter -parameterFilePath 'C:/parameter.json' -valueMap @( @{ Path = pathA;  Value = 'valueA'; replaceToken = '[sasKey]'})

Overwrite all parameter in the parameter.json file that match the path 'pathA' and contain the token 'sasKey' with the values 'valueA' for this token
#>
function Set-CustomParameter {

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory)]
        [string] $parameterFilePath,

        [Parameter(Mandatory)]
        [Array] $valueMap,

        [Parameter(Mandatory = $false)]
        [int] $jsonDepth = 15
    )

    begin {
        Write-Debug ("[{0} entered]" -f $MyInvocation.MyCommand)
    }

    process {
        $paramFileContent = ConvertFrom-Json (Get-Content -Raw -Path $parameterFilePath)

        foreach ($valueItem in $valueMap) {
            $path = $valueItem.Path

            try {
                if ($valueItem.ReplaceToken) {
                    $currentValue = Invoke-Expression "`$paramFileContent.parameters.$path"
                    $targetValue = $currentValue.Replace($valueItem.ReplaceToken, $valueItem.Value)
                    Invoke-Expression "`$paramFileContent.parameters.$path = '$targetValue'"
                }
                elseif ($valueItem.AddToArray) {
                    $currentValue = Invoke-Expression "`$paramFileContent.parameters.$path"
                    $targetValue = $currentValue += $valueItem.Value
                    Invoke-Expression "`$paramFileContent.parameters.$path = '$targetValue'"
                }
                else {
                    $targetValue = $valueItem.Value
                    Invoke-Expression "`$paramFileContent.parameters.$path = '$targetValue'"
                }
            }
            catch {
                Write-Error ("Exception caught. Please doublecheck if the property path [{0}] is valid" -f $valueItem.Path)
                throw $_
            }
        }

        if ($PSCmdlet.ShouldProcess(("Paramter file [{0}]" -f (Split-Path $parameterFilePath -Leaf)), "Overwrite")) {
            ConvertTo-Json $paramFileContent -Depth 15 | Out-File -FilePath $parameterFilePath
            Write-Verbose "Custom parameters added to file"
        }
    }

    end {
        Write-Debug ("[{0} existed]" -f $MyInvocation.MyCommand)
    }
}
