<#
.SYNOPSIS
Register or update a given agent pool that links to a virtual machine scale set

.DESCRIPTION
Register or update a given agent pool that links to a virtual machine scale set

.PARAMETER TemplateFilePath
Required. The template file to fetch deployment information from (e.g. the used Virtual Machine Scale Set name)

.PARAMETER AgentParametersFilePath
Required. The path to the agents configuration file to fetch information from (e.g., the Service Connection name)

.PARAMETER PAT
Mandatory. The PAT token to use to interact with Azure DevOps.
If using the $(System.AccessToken), the 'Project Collection Build Service (<org>)' must at least:
- Be added with level 'User' to the 'Project Settings / Pipelines / Service Connections' security
- Be added with level 'Creator' to the 'Project Settings / Pipelines / Agent pools' security

.EXAMPLE
$inputObject = @{
    TemplateFilePath        = 'C:\dev\ip\DevOps-Self-Hosted\constructs\azureDevOpsScaleSet\deploymentFiles\scaleset.bicep'
    AgentParametersFilePath = 'C:\dev\ip\DevOps-Self-Hosted\constructs\azureDevOpsScaleSet\deploymentFiles\agentpool.config.json'
    PAT                     = '$(System.AccessToken)'
    }
}
Sync-ElasticPool @inputObject

Register/update a scale set agent pool as it is configured in both the 'scaleset.bicep' deployment file & 'agentpool.config.json' configuration file
#>
function Sync-ElasticPool {

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $TemplateFilePath,

        [Parameter(Mandatory = $true)]
        [string] $AgentParametersFilePath,

        [Parameter(Mandatory = $false)]
        [string] $PAT
    )

    begin {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)

        # Load helper
        . (Join-Path -Path $PSScriptRoot 'Get-Project.ps1')
        . (Join-Path -Path $PSScriptRoot 'Get-Endpoint.ps1')
        . (Join-Path -Path $PSScriptRoot 'Get-ElasticPool.ps1')
        . (Join-Path -Path $PSScriptRoot 'New-ElasticPool.ps1')
        . (Join-Path -Path $PSScriptRoot 'Set-ElasticPool.ps1')
        . (Join-Path -Path $PSScriptRoot 'Get-ElasticPoolRegisteredInProject.ps1')
        . (Join-Path -Path $PSScriptRoot 'Set-ElasticPoolRegistrationInProject.ps1')
    }

    process {

        # Fetch information
        # -----------------

        # Get Scale Set propoerties
        $templateContent = az bicep build --file $TemplateFilePath --stdout | ConvertFrom-Json -AsHashtable

        ## Get VMSS name
        if ($templateContent.resources[-1].properties.parameters.Keys -contains 'virtualMachineScaleSetName') {
            # Used explicit value
            $VMSSName = $templateContent.resources[-1].properties.parameters['virtualMachineScaleSetName'].value
        } else {
            # Used default value
            $VMSSName = $templateContent.resources[-1].properties.template.parameters['virtualMachineScaleSetName'].defaultValue
        }

        ## Get VMMS RG name
        if ($templateContent.resources[-1].properties.parameters.Keys -contains 'resourceGroupName') {
            # Used explicit value
            $VMSSResourceGroupName = $templateContent.resources[-1].properties.parameters['resourceGroupName'].value
        } else {
            # Used default value
            $VMSSResourceGroupName = $templateContent.resources[-1].properties.template.parameters['resourceGroupName'].defaultValue
        }

        # Get agent  pool properties
        $agentPoolParameterFileContent = ConvertFrom-Json (Get-Content $AgentParametersFilePath -Raw) -AsHashtable
        $Organization = $agentPoolParameterFileContent.Organization
        $Project = $agentPoolParameterFileContent.Project
        $ServiceConnectionName = $agentPoolParameterFileContent.ServiceConnectionName
        $AgentPoolProperties = $agentPoolParameterFileContent.AgentPoolProperties

        # Logic
        # ----
        if (-not [String]::IsNullOrEmpty($PAT)) {
            Write-Verbose 'Login to AzureDevOps via PAT token' -Verbose
            $env:AZURE_DEVOPS_EXT_PAT = $PAT
        }

        $getVMSSUri = 'https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Compute/virtualMachineScaleSets/{2}?api-version=2022-11-01' -f (Get-AzContext).Subscription.Id, $VMSSResourceGroupName, $VMSSName
        $vmss = (Invoke-AzRestMethod -Method 'GET' -Uri $getVMSSUri).Content | ConvertFrom-Json -AsHashtable
        if ($vmss.Keys -contains 'error') {
            throw $vmss.error.message
        } else {
            Write-Verbose ('Found virtual machine scale set [{0}] in resource group [{1}]' -f $VMSSName, $VMSSResourceGroupName) -Verbose
        }

        if (-not ($foundProject = Get-Project -Organization $Organization -Project $project)) {
            throw ('Unable to find Azure DevOps project [{0}] in organization [{1}]' -f $project, $Organization)
        } else {
            Write-Verbose ('Found Azure DevOps project [{0}] in organization [{1}]' -f $project, $Organization) -Verbose
        }

        $serviceEndpoints = Get-Endpoint -Organization $Organization -Project $project
        if (-not ($serviceEndpoint = $serviceEndpoints | Where-Object { $_.name -eq $serviceConnectionName })) {
            throw ('Unable to find Azure DevOps service connection [{0}] in project [{1}|{2}]' -f $serviceConnectionName, $Organization, $Project)
        } else {
            Write-Verbose ('Found Azure DevOps service connect [{0}] in project [{1}] of organization [{2}]' -f $serviceConnectionName, $project, $Organization) -Verbose
        }

        $elasticPools = Get-ElasticPool -Organization $Organization -Project $project
        if (-not ($elasticPool = $elasticPools | Where-Object { $_.azureId -eq $vmss.Id })) {
            Write-Verbose ('Agent pool for scale set [{0}] in resource group [{1}] not registered, creating new.' -f $vmss.Name, $vmss.ResourceGroupName) -Verbose
            $inputObject = @{
                Organization      = $Organization
                ProjectId         = $foundProject.id
                PoolName          = $AgentPoolProperties.ScaleSetPoolName
                ServiceEndpointId = $serviceEndpoint.id
                VMSSResourceID    = $vmss.id
                VMSSOSType        = $vmss.properties.virtualMachineProfile.storageProfile.osDisk.osType
            }
            if ($AgentPoolProperties.ContainsKey('AuthorizeAllPipelines')) { $inputObject['AuthorizeAllPipelines'] = $AgentPoolProperties.AuthorizeAllPipelines }
            if ($AgentPoolProperties.ContainsKey('MaxCapacity')) { $inputObject['MaxCapacity'] = $AgentPoolProperties.MaxCapacity }
            if ($AgentPoolProperties.ContainsKey('DesiredIdle')) { $inputObject['DesiredIdle'] = $AgentPoolProperties.DesiredIdle }
            if ($AgentPoolProperties.ContainsKey('RecycleAfterEachUse')) { $inputObject['RecycleAfterEachUse'] = $AgentPoolProperties.RecycleAfterEachUse }
            if ($AgentPoolProperties.ContainsKey('MaxSavedNodeCount')) { $inputObject['MaxSavedNodeCount'] = $AgentPoolProperties.MaxSavedNodeCount }
            if ($AgentPoolProperties.ContainsKey('TimeToLiveMinutes')) { $inputObject['TimeToLiveMinutes'] = $AgentPoolProperties.TimeToLiveMinutes }
            if ($AgentPoolProperties.ContainsKey('AgentInteractiveUI')) { $inputObject['AgentInteractiveUI'] = $AgentPoolProperties.AgentInteractiveUI }

            if ($PSCmdlet.ShouldProcess(('Agent pool [{0}]' -f $AgentPoolProperties.ScaleSetPoolName), 'Create')) {
                New-ElasticPool @inputObject
            }
        } else {
            # Check if agent pool is registered to  project, or only the organization
            $inputObject = @{
                Organization = $Organization
                Project      = $Project
                PoolId       = $elasticPool.poolId
            }
            $poolInProjectScope = Get-ElasticPoolRegisteredInProject @inputObject

            if ($poolInProjectScope.Count -eq 0) {
                # Pool not registered in project. Adding...
                $inputObject = @{
                    Organization = $Organization
                    Project      = $Project
                    PoolName     = $AgentPoolProperties.ScaleSetPoolName
                    PoolId       = $elasticPool.poolId
                }
                Write-Verbose ('The agent pool [{0}] exists, but is not yet registered in project [{1}]. Linking.' -f $AgentPoolProperties.ScaleSetPoolName, $Project) -Verbose
                $null = Set-ElasticPoolRegistrationInProject @inputObject
            } else {
                Write-Verbose ('The agent pool [{0}] exists and is registered in project [{1}].' -f $poolInProjectScope.name, $Project) -Verbose
            }
            Write-Verbose ('An agent pool [{0}] with ID [{1}] for scale set [{2}] in resource group [{3}] already exists in organization [{4}]. Updating.' -f $AgentPoolProperties.ScaleSetPoolName, $elasticPool.poolId, $vmss.Name, $vmss.ResourceGroupName, $Organization) -Verbose

            $inputObject = @{
                Organization   = $Organization
                ScaleSetPoolId = $elasticPool.poolId
                VMSSResourceID = $vmss.Id
                VMSSOSType     = $vmss.properties.virtualMachineProfile.storageProfile.osDisk.osType
            }
            if ($AgentPoolProperties.ContainsKey('MaxCapacity')) { $inputObject['MaxCapacity'] = $AgentPoolProperties.MaxCapacity }
            if ($AgentPoolProperties.ContainsKey('DesiredIdle')) { $inputObject['DesiredIdle'] = $AgentPoolProperties.DesiredIdle }
            if ($AgentPoolProperties.ContainsKey('RecycleAfterEachUse')) { $inputObject['RecycleAfterEachUse'] = $AgentPoolProperties.RecycleAfterEachUse }
            if ($AgentPoolProperties.ContainsKey('MaxSavedNodeCount')) { $inputObject['MaxSavedNodeCount'] = $AgentPoolProperties.MaxSavedNodeCount }
            if ($AgentPoolProperties.ContainsKey('TimeToLiveMinutes')) { $inputObject['TimeToLiveMinutes'] = $AgentPoolProperties.TimeToLiveMinutes }
            if ($AgentPoolProperties.ContainsKey('AgentInteractiveUI')) { $inputObject['AgentInteractiveUI'] = $AgentPoolProperties.AgentInteractiveUI }

            if ($PSCmdlet.ShouldProcess(('Agent pool [{0}]' -f $AgentPoolProperties.ScaleSetPoolName), 'Update')) {
                Set-ElasticPool @inputObject
            }
        }
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
