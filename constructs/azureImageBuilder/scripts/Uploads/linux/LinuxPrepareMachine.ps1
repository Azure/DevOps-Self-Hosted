$env:TEMP = '/tmp'

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

function Copy-FileAndFolderList {

    param(
        [string] $sourcePath,
        [string] $targetPath
    )

    $itemsFrom = Get-ChildItem $sourcePath
    foreach ($item in $itemsFrom) {
        if ($item.PSIsContainer) {
            $subsourcePath = $sourcePath + '\' + $item.BaseName
            $subtargetPath = $targetPath + '\' + $item.BaseName
            $null = Copy-FileAndFolderList -sourcePath $subsourcePath -targetPath $subtargetPath
        } else {
            $sourceItemPath = $sourcePath + '\' + $item.Name
            $targetItemPath = $targetPath + '\' + $item.Name
            if (-not (Test-Path $targetItemPath)) {
                # only copies non-existing files
                if (-not (Test-Path $targetPath)) {
                    # if folder doesn't exist, creates it
                    $null = New-Item -ItemType 'directory' -Path $targetPath -Verbose
                }
                $null = Copy-Item $sourceItemPath $targetItemPath
            } else {
                Write-Verbose "[$sourceItemPath] already exists" -Verbose
            }
        }
    }
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
            $installPath = ($env:PSModulePath -split ':')[0]
            $foundModules | Save-Module -Path $installPath -Force

            if ($installed = Get-Module -Name $foundModule.Name -ListAvailable) {
                LogInfo('Module [{0}] is installed with version [{1}] in path [{2}]' -f $installed.Name, $installed.Version, $installPath) -Verbose
            } else {
                LogError('Installation of module [{0}] failed' -f $foundModule.Name)
            }
        }
    }
}
#endregion


$StartTime = Get-Date

###########################
##   Install Azure CLI   ##
###########################
LogInfo('Install azure cli start')
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
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
sudo az aks install-cli
LogInfo('Install kubectl end')

###########################
##   Install Terraform   ##
###########################
LogInfo('Install Terraform start')
$TFVersion = '0.12.30' # Required for layered TF approach (01.2021)
if ([String]::IsNullOrEmpty($TFVersion)) {
    $terraformReleasesUrl = 'https://api.github.com/repos/hashicorp/terraform/releases/latest'
    $latestTerraformVersion = (Invoke-WebRequest -Uri $terraformReleasesUrl -UseBasicParsing | ConvertFrom-Json).name.Replace('v', '')
    LogInfo("Fetched latest available version: [$TFVersion]")
    $TFVersion = $latestTerraformVersion
}

LogInfo("Using version: [$TFVersion]")
sudo apt-get install unzip
wget ('https://releases.hashicorp.com/terraform/{0}/terraform_{0}_linux_amd64.zip' -f $TFVersion)
unzip ('terraform_{0}_linux_amd64.zip' -f $TFVersion )
sudo mv terraform /usr/local/bin/
terraform --version
LogInfo('Install Terraform end')

#######################
##   Install AzCopy   #
#######################
# Cleanup
sudo rm ./downloadazcopy-v10-linux*
sudo rm ./azcopy_linux_amd64_*
sudo rm /usr/bin/azcopy

# Download
wget https://aka.ms/downloadazcopy-v10-linux -O 'downloadazcopy-v10-linux.tar.gz'

# Expand (to azcopy_linux_amd64_x.x.x)
tar -xzvf downloadazcopy-v10-linux.tar.gz

# Move
sudo cp ./azcopy_linux_amd64_*/azcopy /usr/bin/

##################################
##   Install .NET (for Nuget)   ##
##################################
# Source: https://docs.microsoft.com/en-us/dotnet/core/install/linux-ubuntu#1804-
LogInfo('Install dotnet (for nuget) start')
$ubuntuBaseVersion = 18.04

# .NET-Core Runtime
wget https://packages.microsoft.com/config/ubuntu/$ubuntuBaseVersion/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb

# .NET-Core SDK
sudo apt-get update
sudo apt-get install -y apt-transport-https && sudo apt-get update && sudo apt-get install -y dotnet-sdk-5.0

# .NET-Core Runtime
sudo apt-get update
sudo apt-get install -y apt-transport-https && sudo apt-get update && sudo apt-get install -y aspnetcore-runtime-5.0
LogInfo('Install dotnet (for nuget) end')

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
    @{ Name = 'Pester'; Version = '5.1.1' },
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
LogInfo("Copy PS modules to '/opt/microsoft/powershell/7/Modules' start")
$null = Copy-FileAndFolderList -sourcePath '/home/packer/.local/share/powershell/Modules' -targetPath '/opt/microsoft/powershell/7/Modules'
LogInfo('Copy PS modules end')

$elapsedTime = (Get-Date) - $StartTime
$totalTime = '{0:HH:mm:ss}' -f ([datetime]$elapsedTime.Ticks)
LogInfo("Execution took [$totalTime]")
LogInfo('Exiting LinuxPrepareMachine.ps1')

return 0;
#endregion
