<#
.SYNOPSIS
Invoke a REST command for Azure DevOps

.DESCRIPTION
This function takes care of the authentication for you if you're either already logged into az devops or have a PAT token 'AZURE_DEVOPS_EXT_PAT' available in your environment variables
The PAT token supersedes the local login

.PARAMETER method
Mandatory. The method to use for the REST call. E.g. GET, PATCH, DELETE

.PARAMETER uri
Mandatory. The uri to send the REST call towards. E.g. 'https://dev.azure.com/contoso/_apis/projects/My%20Project?api-version=6.0'

.PARAMETER body
Optional. The body to send with the command. Must be in json format. E.g. ConvertTo-Json @{ Make = 'MyDay' } -Depth 10 -Compress

.PARAMETER header
Optional. The header to send with the command. E.g. @{ "Content-Type" = 'application/json' }

.EXAMPLE
Invoke-RESTCommand -method 'GET' -uri 'https://dev.azure.com/contoso/_apis/projects/My%20Project?api-version=6.0'

Fetch the project 'My Project' from organization 'contoso' via REST
#>
function Invoke-RESTCommand {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $method,

        [Parameter(Mandatory = $true)]
        [string] $uri,

        [Parameter(Mandatory = $false)]
        [string] $body,

        [Parameter(Mandatory = $false)]
        [hashtable] $header
    )

    begin {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)

        # Load helper
        . (Join-Path -Path $PSScriptRoot 'Get-ConfigValue.ps1')
    }

    process {
        try {
            $inputObject = @(
                '--method', $method,
                '--uri', $uri,
                '--resource', (Get-ConfigValue -token 'DevOpsPrincipalAppId')  # DevOps resourceAppId (fetched from app manifest in AAD)
            )

            # Build Body
            # ---------
            if ($body) {
                $tmpPath = Join-Path $PSScriptRoot ("REST-$method-{0}.json" -f (New-Guid))
                $body | Out-File -FilePath $tmpPath -Force
                $inputObject += '--body', "@$tmpPath"
            }

            # Build Header
            # -----------
            if (-not $header) {
                $header = @{}
            }
            if (-not [String]::IsNullOrEmpty($env:AZURE_DEVOPS_EXT_PAT)) {
                $inputObject += '--skip-authorization-header'

                # The token cannot be used as is, but must be prased to base64.
                # The authentication could have a 'user' prior to the PAT, but as it's not required we only need the ':' separator
                $encodedToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes((':{0}' -f $env:AZURE_DEVOPS_EXT_PAT)))
                $header['Authorization'] = "Basic $encodedToken"
            }
            $compressedHeader = ConvertTo-Json $header -Depth 10 -Compress
            if ($compressedHeader.length -gt 2) {
                # non-empty
                $tmpPathHeader = Join-Path $PSScriptRoot ("REST-$method-header-{0}.json" -f (New-Guid))
                $compressedHeader | Out-File -FilePath $tmpPathHeader -Force
                $inputObject += '--headers', "@$tmpPathHeader"
            }

            # Execute
            # -------
            try {
                $rawResponse = az rest @inputObject -o json 2>&1
            } catch {
                $rawResponse = $_
            }

            if ($rawResponse.Exception) {
                $rawResponse = $rawResponse.Exception.Message
            }

            # Remove wrappers such as 'Conflict({...})' from the repsonse
            if (($rawResponse -is [string]) -and $rawResponse -match '^[a-zA-Z].+?\((.*)\)$') {
                if ($Matches.count -gt 0) {
                    $rawResponse = $Matches[1]
                }
            }
            if ($rawResponse) {
                if (Test-Json ($rawResponse | Out-String) -ErrorAction 'SilentlyContinue') {
                    return (($rawResponse | Out-String) | ConvertFrom-Json)
                } else {
                    return $rawResponse
                }
            }
        } catch {
            throw $_
        } finally {
            # Remove temp files
            if ((-not [String]::IsNullOrEmpty($tmpPathHeader)) -and (Test-Path $tmpPathHeader)) {
                Remove-Item -Path $tmpPathHeader -Force
            }
            if ((-not [String]::IsNullOrEmpty($tmpPath)) -and (Test-Path $tmpPath)) {
                Remove-Item -Path $tmpPath -Force
            }
        }
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
