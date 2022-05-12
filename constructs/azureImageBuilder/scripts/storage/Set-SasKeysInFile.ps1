function Set-SasKeysInFile {

	[CmdletBinding(SupportsShouldProcess)]
	param (
		[Parameter()]
		[string] $filePath
	)

	begin {
		Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)

		# Install required modules
		$currentVerbosePreference = $VerbosePreference
		$VerbosePreference = 'SilentlyContinue'
		$requiredModules = @(
			'Az.ResourceGraph'
		)
		foreach ($moduleName in $requiredModules) {
			if (-not ($installedModule = Get-Module $moduleName -ListAvailable)) {
				Install-Module $moduleName -Repository 'PSGallery' -Force -Scope 'CurrentUser'
				if ($installed = Get-Module -Name $moduleName -ListAvailable) {
					Write-Verbose ('Installed module [{0}] with version [{1}]' -f $installed.Name, $installed.Version) -Verbose
				}
			} else {
				Write-Verbose ('Module [{0}] already installed in version [{1}]' -f $installedModule.Name, $installedModule.Version) -Verbose
			}
		}

		$VerbosePreference = $currentVerbosePreference
	}

	process {
		$parameterFileContent = Get-Content -Path $filePath
		$saslines = $parameterFileContent | Where-Object { $_ -match '^[^/]*:.*<SAS>.*$' } | ForEach-Object { $_.Trim() }

		Write-Verbose ('Found [{0}] lines with sas tokens (<SAS>) to replace' -f $saslines.Count)

		foreach ($line in $saslines) {
			Write-Verbose "Evaluate line [$line]" -Verbose
			$null = $line -cmatch 'https.*<SAS>'
			$fullPath = $Matches[0].Replace('https://', '').Replace('<SAS>', '')
			$pathElements = $fullPath.Split('/')
			$containerName = $pathElements[1]
			$fileName = $pathElements[2]
			$storageAccountName = $pathElements[0].Replace('.blob.core.windows.net', '')

			$storageAccountResource = Search-AzGraph -Query "Resources | where name =='$storageAccountName'"

			if (-not $storageAccountResource) {
				throw "Storage account [$storageAccountName] not found"
			}

			$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $storageAccountResource.resourceGroup -Name $storageAccountName)[0].Value
			$storageContext = New-AzStorageContext $StorageAccountName -StorageAccountKey $storageAccountKey

			$sasToken = New-AzStorageBlobSASToken -Container $containerName -Blob $fileName -Permission 'r' -StartTime (Get-Date) -ExpiryTime (Get-Date).AddHours(2) -Context $storageContext

			$newString = $line.Replace('<SAS>', $sasToken)

			$parameterFileContent = $parameterFileContent.Replace($line, $newString)
		}

		if ($PSCmdlet.ShouldProcess("File in path [$filePath]", 'Overwrite')) {
			Set-Content -Path $filePath -Value $parameterFileContent -Force
		}
	}

	end {
		Write-Debug ('{0} existed' -f $MyInvocation.MyCommand)
	}
}
