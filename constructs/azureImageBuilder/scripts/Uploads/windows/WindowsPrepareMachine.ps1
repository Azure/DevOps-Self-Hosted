#region Functions
function LogInfo($message) {
    Log 'Info' $message
}

function LogError($message) {
    Log 'Error' $message
}

function LogWarning($message) {
    Log 'Warning' $message
}

function Log {

    <#
    .SYNOPSIS
    Creates a log file and stores logs based on categories with tab seperation

    .PARAMETER category
    Category to put into the trace

    .PARAMETER message
    Message to be loged

    .EXAMPLE
    Log 'Info' 'Message'

    #>

    Param (
        [Parameter(Mandatory = $false)]
        [string] $category = 'Info',

        [Parameter(Mandatory = $true)]
        [string] $message
    )

    $date = Get-Date
    $content = "[$date]`t$category`t`t$message`n"
    Write-Verbose $Content -Verbose

    $FilePath = Join-Path $env:TEMP 'log.log'
    if (-not (Test-Path $FilePath)) {
        Write-Verbose "Log file not found, create new in path: [$FilePath]" -Verbose
        $null = New-Item -ItemType 'File' -Path $FilePath -Force
    }
    Add-Content -Path $FilePath -Value $content -ErrorAction 'Stop'
}

function Install-CustomModule {

    <#
    .SYNOPSIS
    Installes given PowerShell modules

    .DESCRIPTION
    Installes given PowerShell modules

    .PARAMETER Module
    Required. Modules to be installed, must be Object
    @{
        Name = 'Name'
        Version = '1.0.0' # Optional
    }

    .PARAMETER InstalledModule
    Optional. Modules that are already installed on the machine. Can be fetched via 'Get-Module -ListAvailable'

    .EXAMPLE
    Install-CustomModule @{ Name = 'Pester' } C:\Modules

    Installes pester and saves it to C:\Modules
    #>

    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(Mandatory = $true)]
        [Hashtable] $Module,

        [Parameter(Mandatory = $false)]
        [object[]] $InstalledModule = @()
    )

    # Remove exsisting module in session
    if (Get-Module $Module -ErrorAction 'SilentlyContinue') {
        try {
            Remove-Module $Module -Force
        } catch {
            LogError('Unable to remove module [{0}] because of exception [{1}]. Stack Trace: [{2}]' -f $Module.Name, $_.Exception, $_.ScriptStackTrace)
        }
    }

    # Install found module
    $moduleImportInputObject = @{
        name       = $Module.Name
        Repository = 'PSGallery'
    }
    if ($Module.Version) {
        $moduleImportInputObject['RequiredVersion'] = $Module.Version
    }

    # Get all modules that match a certain name. In case of e.g. 'Az' it returns several.
    $foundModules = Find-Module @moduleImportInputObject

    foreach ($foundModule in $foundModules) {

        # Check if already installed as required
        if ($alreadyInstalled = $InstalledModule | Where-Object { $_.Name -eq $Module.Name }) {
            if ($Module.Version) {
                $alreadyInstalled = $alreadyInstalled | Where-Object { $_.Version -eq $Module.Version }
            } else {
                # Get latest in case of multiple
                $alreadyInstalled = ($alreadyInstalled | Sort-Object -Property Version -Descending)[0]
            }
            LogInfo('Module [{0}] already installed with version [{1}]' -f $alreadyInstalled.Name, $alreadyInstalled.Version) -Verbose
            continue
        }

        # Check if not to be excluded
        if ($Module.ExcludeModules -and $Module.excludeModules.contains($foundModule.Name)) {
            LogInfo('Module {0} is configured to be ignored.' -f $foundModule.Name) -Verbose
            continue
        }

        LogInfo('Install module [{0}] with version [{1}]' -f $foundModule.Name, $foundModule.Version) -Verbose
        if ($PSCmdlet.ShouldProcess('Module [{0}]' -f $foundModule.Name, 'Install')) {
            # $foundModule | Install-Module -Force -SkipPublisherCheck -AllowClobber
            $installPath = ($env:PSModulePath -split ';')[0]
            $foundModules | Save-Module -Path $installPath -Force

            if ($installed = Get-Module -Name $foundModule.Name -ListAvailable) {
                LogInfo('Module [{0}] is installed with version [{1}] in path [{2}]' -f $installed.Name, $installed.Version, $installPath) -Verbose
            } else {
                LogError('Installation of module [{0}] failed' -f $foundModule.Name)
            }
        }
    }
}

function Set-PowerShellOutputRedirectionBugFix {

    [CmdletBinding(SupportsShouldProcess)]
    param ()

    $poshMajorVerion = $PSVersionTable.PSVersion.Major

    if ($poshMajorVerion -lt 4) {
        try {
            # http://www.leeholmes.com/blog/2008/07/30/workaround-the-os-handles-position-is-not-what-filestream-expected/ plus comments
            $bindingFlags = [Reflection.BindingFlags] 'Instance,NonPublic,GetField'
            $objectRef = $host.GetType().GetField('externalHostRef', $bindingFlags).GetValue($host)
            $bindingFlags = [Reflection.BindingFlags] 'Instance,NonPublic,GetProperty'
            $consoleHost = $objectRef.GetType().GetProperty('Value', $bindingFlags).GetValue($objectRef, @())
            [void] $consoleHost.GetType().GetProperty('IsStandardOutputRedirected', $bindingFlags).GetValue($consoleHost, @())
            $bindingFlags = [Reflection.BindingFlags] 'Instance,NonPublic,GetField'
            $field = $consoleHost.GetType().GetField('standardOutputWriter', $bindingFlags)

            if ($PSCmdlet.ShouldProcess('OutputWriter field [Out]', 'Set')) {
                $field.SetValue($consoleHost, [Console]::Out)
            }

            [void] $consoleHost.GetType().GetProperty('IsStandardErrorRedirected', $bindingFlags).GetValue($consoleHost, @())
            $field2 = $consoleHost.GetType().GetField('standardErrorWriter', $bindingFlags)

            if ($PSCmdlet.ShouldProcess('OutputWriter field [Error]', 'Set')) {
                $field2.SetValue($consoleHost, [Console]::Error)
            }
        } catch {
            LogInfo( 'Unable to apply redirection fix.')
        }
    }
}

function Get-Downloader {
    param (
        [string]$url
    )

    $downloader = New-Object System.Net.WebClient

    $defaultCreds = [System.Net.CredentialCache]::DefaultCredentials
    if ($null -ne $defaultCreds) {
        $downloader.Credentials = $defaultCreds
    }

    if ($env:chocolateyIgnoreProxy -eq 'true') {
        Write-Debug 'Explicitly bypassing proxy due to user environment variable'
        $downloader.Proxy = [System.Net.GlobalProxySelection]::GetEmptyWebProxy()
    } else {
        # check if a proxy is required
        $explicitProxy = $env:chocolateyProxyLocation
        $explicitProxyUser = $env:chocolateyProxyUser
        $explicitProxyPassword = $env:chocolateyProxyPassword
        if ($null -ne $explicitProxy -and $explicitProxy -ne '') {
            # explicit proxy
            $proxy = New-Object System.Net.WebProxy($explicitProxy, $true)
            if ($null -ne $explicitProxyPassword -and $explicitProxyPassword -ne '') {
                $passwd = ConvertTo-SecureString $explicitProxyPassword -AsPlainText -Force
                $proxy.Credentials = New-Object System.Management.Automation.PSCredential ($explicitProxyUser, $passwd)
            }

            Write-Debug "Using explicit proxy server '$explicitProxy'."
            $downloader.Proxy = $proxy

        } elseif (-not $downloader.Proxy.IsBypassed($url)) {
            # system proxy (pass through)
            $creds = $defaultCreds
            if ($null -eq $creds) {
                Write-Debug 'Default credentials were null. Attempting backup method'
                $cred = Get-Credential
                $creds = $cred.GetNetworkCredential();
            }

            $proxyaddress = $downloader.Proxy.GetProxy($url).Authority
            Write-Debug "Using system proxy server '$proxyaddress'."
            $proxy = New-Object System.Net.WebProxy($proxyaddress)
            $proxy.Credentials = $creds
            $downloader.Proxy = $proxy
        }
    }

    return $downloader
}

function Get-DownloadString {
    param (
        [string]$url
    )
    $downloader = Get-Downloader $url

    return $downloader.DownloadString($url)
}

function Get-DownloadedFile {
    param (
        [string]$url,
        [string]$file
    )
    LogInfo( "Downloading $url to $file")
    $downloader = Get-Downloader $url

    $downloader.DownloadFile($url, $file)
}

function Set-SecurityProtocol {

    [CmdletBinding(SupportsShouldProcess)]
    param (
    )

    # Attempt to set highest encryption available for SecurityProtocol.
    # PowerShell will not set this by default (until maybe .NET 4.6.x). This
    # will typically produce a message for PowerShell v2 (just an info
    # message though)
    try {
        # Set TLS 1.2 (3072), then TLS 1.1 (768), then TLS 1.0 (192), finally SSL 3.0 (48)
        # Use integers because the enumeration values for TLS 1.2 and TLS 1.1 won't
        # exist in .NET 4.0, even though they are addressable if .NET 4.5+ is
        # installed (.NET 4.5 is an in-place upgrade).
        if ($PSCmdlet.ShouldProcess('Security protocol', 'Set')) {
            [System.Net.ServicePointManager]::SecurityProtocol = 3072 -bor 768 -bor 192 -bor 48
        }
    } catch {
        LogInfo( 'Unable to set PowerShell to use TLS 1.2 and TLS 1.1 due to old .NET Framework installed. If you see underlying connection closed or trust errors, you may need to do one or more of the following: (1) upgrade to .NET Framework 4.5+ and PowerShell v3, (2) specify internal Chocolatey package location (set $env:chocolateyDownloadUrl prior to install or host the package internally), (3) use the Download + PowerShell method of install. See https://chocolatey.org/install for all install options.')
    }
}

function Install-Choco {

    LogInfo( 'Install choco')

    LogInfo( 'Invoke install.ps1 content')
    if ($null -eq $env:TEMP) {
        $env:TEMP = Join-Path $env:SystemDrive 'temp'
    }
    $chocTempDir = Join-Path $env:TEMP 'chocolatey'
    $tempDir = Join-Path $chocTempDir 'chocInstall'
    if (-not [System.IO.Directory]::Exists($tempDir)) { [void][System.IO.Directory]::CreateDirectory($tempDir) }
    $file = Join-Path $tempDir 'chocolatey.zip'

    Set-PowerShellOutputRedirectionBugFix

    Set-SecurityProtocol

    LogInfo( 'Getting latest version of the Chocolatey package for download.')
    $url = 'https://chocolatey.org/api/v2/Packages()?$filter=((Id%20eq%20%27chocolatey%27)%20and%20(not%20IsPrerelease))%20and%20IsLatestVersion'
    [xml]$result = Get-DownloadString $url
    $url = $result.feed.entry.content.src

    # Download the Chocolatey package
    LogInfo("Getting Chocolatey from $url.")
    Get-DownloadedFile $url $file

    # Determine unzipping method
    # 7zip is the most compatible so use it by default
    $7zaExe = Join-Path $tempDir '7za.exe'
    $unzipMethod = '7zip'
    if ($env:chocolateyUseWindowsCompression -eq 'true') {
        LogInfo( 'Using built-in compression to unzip')
        $unzipMethod = 'builtin'
    } elseif (-Not (Test-Path ($7zaExe))) {
        LogInfo( 'Downloading 7-Zip commandline tool prior to extraction.')
        # download 7zip
        Get-DownloadedFile 'https://chocolatey.org/7za.exe' "$7zaExe"
    }

    # unzip the package
    LogInfo("Extracting $file to $tempDir...")
    if ($unzipMethod -eq '7zip') {
        LogInfo('Unzip with 7zip')
        $params = "x -o`"$tempDir`" -bd -y `"$file`""
        # use more robust Process as compared to Start-Process -Wait (which doesn't
        # wait for the process to finish in PowerShell v3)
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = New-Object System.Diagnostics.ProcessStartInfo($7zaExe, $params)
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $process.Start() | Out-Null
        $process.BeginOutputReadLine()
        $process.WaitForExit()
        $exitCode = $process.ExitCode
        $process.Dispose()
        $errorMessage = "Unable to unzip package using 7zip. Perhaps try setting `$env:chocolateyUseWindowsCompression = 'true' and call install again. Error:"
        switch ($exitCode) {
            0 { LogInfo('Processed zip'); break }
            1 { throw "$errorMessage Some files could not be extracted" }
            2 { throw "$errorMessage 7-Zip encountered a fatal error while extracting the files" }
            7 { throw "$errorMessage 7-Zip command line error" }
            8 { throw "$errorMessage 7-Zip out of memory" }
            255 { throw "$errorMessage Extraction cancelled by the user" }
            default { throw "$errorMessage 7-Zip signalled an unknown error (code $exitCode)" }
        }
    } else {
        LogInfo('Unzip without 7zip')
        if ($PSVersionTable.PSVersion.Major -lt 5) {
            try {
                $shellApplication = New-Object -com shell.application
                $zipPackage = $shellApplication.NameSpace($file)
                $destinationFolder = $shellApplication.NameSpace($tempDir)
                $destinationFolder.CopyHere($zipPackage.Items(), 0x10)
            } catch {
                throw "Unable to unzip package using built-in compression. Set `$env:chocolateyUseWindowsCompression = 'false' and call install again to use 7zip to unzip. Error: `n $_"
            }
        } else {
            Expand-Archive -Path "$file" -DestinationPath "$tempDir" -Force
        }
    }

    # Call chocolatey install
    LogInfo( 'Installing chocolatey on this machine')
    $toolsFolder = Join-Path $tempDir 'tools'
    $chocInstallPS1 = Join-Path $toolsFolder 'chocolateyInstall.ps1'

    & $chocInstallPS1

    LogInfo( 'Ensuring chocolatey commands are on the path')
    $chocInstallVariableName = 'ChocolateyInstall'
    $chocoPath = [Environment]::GetEnvironmentVariable($chocInstallVariableName)
    if ($null -eq $chocoPath -or $chocoPath -eq '') {
        $chocoPath = "$env:ALLUSERSPROFILE\Chocolatey"
    }

    if (-not (Test-Path ($chocoPath))) {
        $chocoPath = "$env:SYSTEMDRIVE\ProgramData\Chocolatey"
    }

    $chocoExePath = Join-Path $chocoPath 'bin'

    if ($($env:Path).ToLower().Contains($($chocoExePath).ToLower()) -eq $false) {
        $env:Path = [Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine);
    }

    LogInfo( 'Ensuring chocolatey.nupkg is in the lib folder')
    $chocoPkgDir = Join-Path $chocoPath 'lib\chocolatey'
    $nupkg = Join-Path $chocoPkgDir 'chocolatey.nupkg'
    if (-not [System.IO.Directory]::Exists($chocoPkgDir)) { [System.IO.Directory]::CreateDirectory($chocoPkgDir); }
    Copy-Item "$file" "$nupkg" -Force -ErrorAction SilentlyContinue
}


function Uninstall-AzureRM {
    <#
    .SYNOPSIS
    Removes AzureRM from system

    .EXAMPLE
    Uninstall-AzureRM
    Removes AzureRM from system

    #>

    LogInfo('Remove Modules from context start')
    Get-Module 'AzureRM.*' | Remove-Module
    LogInfo('Remaining AzureRM modules: {0}' -f ((Get-Module 'AzureRM.*').Name -join ' | '))
    LogInfo('Remove Modules from context end')

    # Uninstalling Azure PowerShell Modules
    try {
        $programName = 'Microsoft Azure PowerShell'
        $retry = $false
        try {
            LogInfo("Remove Program $programName")
            Remove-Program -Like "$programName*"
            LogInfo("Removed Program $programName")
        } catch {
            LogWarning("'$($programName) msiexec removal failed, retry uninstall")
            $retry = $true
        }

        if ($retry) {
            try {
                $app = Get-CimInstance -Class Win32_Product -Filter "Name Like '$($programName)%'" -Verbose
                if ($app) {
                    LogInfo("Found $($app.Name), try uninstall ")
                    $app.Uninstall()
                } else {
                    LogWarning("'$($programName) not found")
                }
            } catch {
                LogError("'$($programName) uninstall failed")
            }
        }

    } catch {
        LogError("Unable to remove Microsoft Azure PowerShell: $($_.Exception) found, $($_.ScriptStackTrace)")
    }

    # Uninstall AzureRm Module
    try {
        Get-Module 'AzureRm.*' -ListAvailable | Uninstall-Module -Force
    } catch {
        LogError("Unable to remove AzureRM Module: $($_.Exception) found, $($_.ScriptStackTrace)")
    }

    try {
        $AzureRMModuleFolder = 'C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ResourceManager\AzureResourceManager'
        Remove-Item $AzureRMModuleFolder -Force -Recurse
        LogInfo("Removed $AzureRMModuleFolder")
    } catch {
        LogError("Unable to remove $AzureRMModuleFolder")
    }

    LogInfo('Remaining installed AzureRMModule: {0}' -f ((Get-Module 'AzureRM.*' -ListAvailable).Name -join ' | '))
}
#endregion

$StartTime = Get-Date

LogInfo( 'Set Execution Policy')
Set-ExecutionPolicy Bypass -Scope Process -Force

#######################
##   Install Choco    #
#######################
LogInfo('Install-Choco start')
$null = Install-Choco
LogInfo('Install-Choco end')

##########################
##   Install Azure CLI   #
##########################
LogInfo('Install azure cli start')
$null = choco install azure-cli -y -v
LogInfo('Install azure cli end')

###############################
##   Install Extensions CLI   #
###############################

LogInfo('Install cli exentions start')
$Extensions = @(
    'azure-devops'
)
foreach ($extension in $Extensions) {
    if ((az extension list-available -o json | ConvertFrom-Json).Name -notcontains $extension) {
        Write-Verbose "Adding CLI extension '$extension'"
        az extension add --name $extension
    }
}
LogInfo('Install cli exentions end')

##########################
##   Install Az Bicep    #
##########################
LogInfo('Install az bicep exention start')
az bicep install
LogInfo('Install az bicep exention end')

#########################
##   Install Kubectl    #
#########################
LogInfo('Install kubectl start')
$null = choco install kubernetes-cli -y -v
LogInfo('Install kubectl end')

#################################
##   Install PowerShell Core    #
#################################
LogInfo('Install powershell core start')
$null = choco install powershell-core -y -v
LogInfo('Install powershell core end')

###########################
##   Install Terraform   ##
###########################
LogInfo('Install Terraform start')
$null = choco install terraform -y -v
LogInfo('Install Terraform end')

#######################
##   Install Nuget   ##
#######################
LogInfo('Update Package Provider Nuget start')
$null = Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
LogInfo('Update Package Provider Nuget end')

#######################
##   Install AzCopy   #
#######################
LogInfo('Install az copy start')
Invoke-WebRequest -Uri 'https://aka.ms/downloadazcopy-v10-windows' -OutFile 'AzCopy.zip' -UseBasicParsing
Expand-Archive './AzCopy.zip' './AzCopy' -Force
Get-ChildItem './AzCopy/*/azcopy.exe' | Move-Item -Destination 'C:\Users\thmaure\AzCopy\AzCopy.exe'
$userenv = [System.Environment]::GetEnvironmentVariable('Path', 'User')
[System.Environment]::SetEnvironmentVariable('PATH', $userenv + ';C:\Users\thmaure\AzCopy', 'User')
LogInfo('Install az copy end')

###########################
##   Install BICEP CLI   ##
###########################
LogInfo('Install BICEP start')

# Fetch the latest Bicep CLI binary
curl -Lo bicep 'https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64'
# Mark it as executable
chmod +x ./bicep
# Add bicep to your PATH (requires admin)
sudo mv ./bicep /usr/local/bin/bicep
LogInfo('Install BICEP end')

###############################
##   Install PowerShellGet   ##
###############################
LogInfo('Install latest PowerShellGet start')
$null = Install-Module 'PowerShellGet' -Force
LogInfo('Install latest PowerShellGet end')

LogInfo('Import PowerShellGet start')
$null = Import-PackageProvider PowerShellGet -Force
LogInfo('Import PowerShellGet end')

####################################
##   Install PowerShell Modules   ##
####################################
$Modules = @(
    @{ Name = 'Pester' },
    @{ Name = 'PSScriptAnalyzer' },
    @{ Name = 'powershell-yaml' },
    @{ Name = 'Azure.*'; ExcludeModules = @('Azure.Storage') }, # Azure.Storage has AzureRM dependency
    @{ Name = 'Logging' },
    @{ Name = 'PoshRSJob' },
    @{ Name = 'ThreadJob' },
    @{ Name = 'JWTDetails' },
    @{ Name = 'OMSIngestionAPI' },
    @{ Name = 'Az' },
    @{ Name = 'AzureAD' },
    @{ Name = 'ImportExcel' }
)
$count = 0
LogInfo('Try installing:')
$modules | ForEach-Object {
    LogInfo('- [{0}]. [{1}]' -f $count, $_.Name)
    $count++
}

# Load already installed modules
$installedModules = Get-Module -ListAvailable

LogInfo('Install-CustomModule start')
$count = 0
Foreach ($Module in $Modules) {
    LogInfo('=====================')
    LogInfo('HANDLING MODULE [{0}] [{1}/{2}]' -f $Module.Name, $count, $Modules.Count)
    LogInfo('=====================')
    # Installing New Modules and Removing Old
    $null = Install-CustomModule -Module $Module -InstalledModule $installedModules
    $count++
}
LogInfo('Install-CustomModule end')

#########################################
##   Post Installation Configuration   ##
#########################################
if (Get-Module AzureRm* -ListAvailable) {
    LogInfo('Un-install ARM start')
    Uninstall-AzureRm
    LogInfo('Un-install ARM end')
}

$elapsedTime = (Get-Date) - $StartTime
$totalTime = '{0:HH:mm:ss}' -f ([datetime]$elapsedTime.Ticks)
LogInfo("Execution took [$totalTime]")
LogInfo('Exiting WindowsPrepareMachine.ps1')

return 0;
#endregion
