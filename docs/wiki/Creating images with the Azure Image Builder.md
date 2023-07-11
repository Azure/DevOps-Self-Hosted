This sections gives you an overview on how to use the Azure Image Builder (AIB) pipeline to deploy the required infrastructure for, and build images with the Azure Image Builder.

### _Navigation_
- [Overview](#overview)
- [Process](#process)
  - [Initial configuration](#initial-configuration)
  - [Deployment](#deployment)
    - [First deployment](#first-deployment)
    - [Consecutive deployments](#consecutive-deployments)
- [Out of the box installed components](#out-of-the-box-installed-components)
- [Troubleshooting](#troubleshooting)

# Overview
The image creation uses several components:

| &nbsp;&nbsp;&nbsp; | Resource | Description |
|--|--|--|
| <img src="./media/icons/Resource-Groups.svg" alt="ResourceGroup" height="12"> | Resource Group | The resource group hosting our image resources |
| <img src="./media/icons/Storage-Accounts.svg" alt="Storage Account" height="12"> | Storage Account | The storage account that hosts our image customization scripts used by the _Azure Image Building_ when executing the image template |
| <img src="./media/icons/Managed-identities.svg" alt="Managed Identity" height="12"> | User-Assigned Managed Identity | Azure Active Directory feature that eliminates the need for credentials in code, rotates credentials automatically, and reduces identity maintenance. In the context of the imaging construct, the managed identity (MSI) is used by the Image Builder Service. It requires contributor permissions on the subscription to be able to bake the image. |
| <img src="./media/icons/AzureComputeGalleries.svg" alt="Azure Compute Gallery" height="12"> | Azure Compute Gallery | Azure service that helps to build structure and organization for managed images. Provides global replication, versioning, grouping, sharing across subscriptions and scaling. The plain resource in itself is like an empty container. |
| <img src="./media/icons/VMImageDefinitions.svg" alt="Azure Compute Gallery Image" height="12"> | Azure Compute Gallery Image | Created within a gallery and contains information about the image and requirements for using it internally. This includes metadata like whether the image is Windows or Linux, release notes and recommended compute resources. Like the image gallery itself it acts like a container for the actual images. |
| <img src="./media/icons/ImageTemplates.svg" alt="Image Template" height="12"> | Image Template | A standard Azure Image Builder template that defines the parameters for building a custom image with AIB. The parameters include image source (Marketplace, custom image, etc.), customization options (i.e., Updates, scripts, restarts), and distribution (i.e., managed image, Azure Compute Gallery). The template is not an actual resource. Instead, when an image template is created, Azure stores all the metadata of the referenced Azure Compute Gallery Image alongside other image backing instructions as a hidden resource in a temporary resource group. |
| <img src="./media/icons/VMImageVersions.svg" alt="Image Version" height="12"> | Image Version | An image version (for example `0.24322.55884`) is what you use to create a VM when using a gallery. You can have multiple versions of an image as needed for your environment. This value **cannot** be chosen. |

<p>

<img src="./media/image/imageBuilderimage.png" alt="Run workflow" height="150">

<p>

> _**NOTE:**_ The construct was build with multiple environments and staging in mind. To this end, pipeline variable files contain one variable per suggested environment (for example `vmImage_sbx` & `vmImage_dev`) which is automatically referenced by the corresponding stage. For details on how to work with and configure these variables, please refer to this [section](./Staging).
>
> For the rest of the documentation we will ignore these environments and just refer to the simple variable or parameter file to avoid confusion around which file we refer to. All concepts apply to all files, no matter the environment/stage.

# Process

This section explains how to deploy the image pipeline construct and use it on a continuous basis.

## Initial configuration

To prepare the construct for usage you have to perform two fundamental steps:

<details>
<summary>1. Configure the deployment parameters</summary>

For this step you have to update these files to your needs:
- `.azuredevops\azureImageBuilder\variables.yml`
- `constructs\azureImageBuilder\Parameters\imageInfra.bicep`
- `constructs\azureImageBuilder\Parameters\imageTemplate.bicep`

### Variables
The first file, `variables.yml`, is a pipeline variable file. You should update at least the values:
- `vmImage`: Set this to for example `ubuntu-latest` to leverage Microsoft-hosted agents. Leave it empty (`''`) if you use self-hosted agents. Do not remove it.
- `poolName`: Set this to for example `myHostPool` to leverage your self-hosted agent pool. Leave it empty (`''`) if you use Microsoft-hosted agents. Do not remove it.
- `serviceConnection`: This refers to your Azure DevOps service connection you use for your deployments. It should point into the subscription you want to deploy into.
- `location`: The location to store deployment metadata in. This variable is also used as a default location to deploy into, if no location is provided in the parameter files.

### Parameters
Next, we have two deployment files, `imageInfra.bicep` & `imageTemplate.bicep` that correspond to the two phases in the deployment: Deploy all infrastructure components & build the image.

Each file comes with out-of-the box parameters that you can use aside from a few noteworthy exceptions:
- Update any name of a resource that is deployed and must be globally unique (for example storage accounts).
- Update any reference to the a resource accordingly. For example, the storage account you specify in the `imageInfra.bicep` parameter file should be the same you then reference in the `imageTemplate.bicep`'s `imageTemplateCustomizationSteps` parameter.

> **Note:** To keep the parameter files as simple as possible, all values that don't necessarily need you attention are hardcoded as default values in the corresponding template files. To get an overview about these 'defaults', you can simply navigate from the parameter file to the linked template.

The parameter files are created with a Linux-Image in mind. However, they also contain examples on how the same implementation would look like for Windows images. Examples are always commented and can be used to replace the currently not commented values.

As the deployments leverage [`CARML`](https://aka.ms/CARML) modules you can find a full list of all supported parameters per module in that repository's modules. A valid example may be that you want to deploy the Image Template into a specific subnet for networking access. This and several other parameters are available and documented in the module's `readme.md`.

#### Special case: **Image Template**

The image template ultimately decides what happens during the image built. In this construct, it works in combination with the PowerShell scripts provided in the `constructs\azureImageBuilder\scripts\Uploads` folder.

When you eventually trigger the pipeline, it will upload any script in the `Uploads` folder to a dedicated storage account for the image building process and then execute it as per the configured steps in the Image Template's parameter file's `customizationSteps` parameter. For Linux we use for example the following two steps:

```Bicep
imageTemplateCustomizationSteps: [
  {
      type: 'Shell'
      name: 'PowerShell installation'
      scriptUri: 'https://<YourStorageAccount>.blob.core.windows.net/aibscripts/LinuxInstallPowerShell.sh?${sasKey}'
  }
  {
      type: 'Shell'
      name: 'Prepare software installation'
      inline: [
          'wget \'https://<YourStorageAccount>.blob.core.windows.net/aibscripts/LinuxPrepareMachine.ps1?${sasKey}\' -O \'LinuxPrepareMachine.ps1\''
          'sed -i \'s/\r$//' 'LinuxPrepareMachine.ps1\''
          'pwsh \'LinuxPrepareMachine.ps1\''
      ]
  }
]
```

It first installs PowerShell on the target machine and then continues by executing the installation script. Feel free to modify the existing script, or add new ones with new customization steps as you see fit. You can find a full list of all available steps [here](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json#properties-customize).

</details>

<details>
<summary>2. Register the pipeline</summary>

With the parameters configured, you can now continue and register the pipeline in Azure DevOps.

To do so, you have to perform the following steps:

1. Navigate to the Azure DevOps project you want to register the pipeline in
1. Select `Pipelines` to the left and further its `Pipelines` sub-section

   <img src="./media/shared/devOpsPipelineMenu.png" alt="Select pipeline menu" height="120">

1. Now select `New pipeline` on the top right

   <img src="./media/shared/devOpsPipelineInitNew.png" alt="Select new pipeline" height="100">

1. Next, select the location of you pipeline file. If you host the repository in GitHub, select `GitHub`, or for example `Azure Repos Git` if you host the code in Azure DevOps's own git.

1. In the opening `Select` step, select your repository

1. In the opening `Configure` step, select `Existing Azure Ppelines YAML`

1. In the opening blade, select the `Branch` your code is in, and in `Path` the pipeline's path. Once done, select `Continue` on the bottom right

1. In the opening `Review` step, you can now see the pipeline you select and can either select `Run` or (via the dropdown) `Save` on the top right.

1. Optionally, once saved, you can rename & move the pipeline by selecting the three '`...`' on the top right, and select `Rename/move`

   <img src="./media/shared/renameMove.png" alt="Rename or move" height="300">

</details>

## Deployment

The creation of the image alongside its resources is handled by the `.azuredevops\azureImageBuilder\pipeline.yml` pipeline. Given the proper configuration, it creates all required resources in the designated environment and optionally triggers the image creation right after.

  <img src="./media/image/imagetrigger.PNG" alt="Run workflow" height="400">

So let's take a look at the different configuration options when running the pipeline:

| Runtime Parameter | Description | On first deployment | Additional notes |
| - | - | - | - |
| `Environment to start from` | The environment you want to start to deploy into as described [here](./Staging#3-run-the-pipeline)  | Set to `SBX` | |
| `Scope of deployment` | Select whether you want to deploy all resources, all resources without triggering the image build, or only the image build | Set to deploy `All` or `Only Infrastructure` resources | Overall you have the following options: <p> <li>**`All`**: Deploys all resources end-to-end including an image build</li><li>**`Only removal`**: Only removes previous image templates (and their AIB resource groups) that match the provided Image Template name and are not in state `running`. Further, terminated deployment scripts who's name starts with the `defaultPrefix` specified in the `sbx.imageTemplate.bicep` file are removed. Is only executed if the `Pre-remove Image Template Resource Group` checkbox is selected too.</li><li>**`Only infrastructure`**: Deploys everything, but the image template. As such, no image is built</li><li>**`Only storage & image`**: Only deploy the storage account, upload the latest installation files from the `Uploads` folder and trigger an image build</li><li>**`Only image`**: Only trigger an image build</li> |
| `Wait for image build` |  Specify whether to wait for the image build process during the pipeline run or not. The process itself is triggered asynchronously. | De-Select |  You can use the 'Wait-ForImageBuild' script to check the status yourself (located at: `constructs\azureImageBuilder\scripts\image\Wait-ForImageBuild.ps1`). <p> To execute it you will need the image template name (output value of the image template deployment) and the resource group the image template was deployed into. Is only considered, if the `Scope of the deployment` includes an image build. |
| `Pre-remove Image Template Resource Group` | Specify whether to remove previous image resources. This includes all Image Templates that match the naming schema defined in the parameter file - as long es their built is not in state `running`.  | De-select | |

### First deployment
When triggering the pipeline for the first time for any environment, make sure you either select `All` or `Only Infrastructure` for the `Scope of the deployment`. In either case the pipeline will deploy all resources and scripts you will subsequently need to create the images. For any subsequent run, you can go with any option you need.

If you did not select `All` you can then decide at any point to re-run the pipeline using the `All`, `Only storage & image` or `Only image` options respectively to have the image template being built.

The steps the _Azure Image Builder_ performs on the image are defined by elements configured in the `customizationSteps` parameter of the image template parameter file. In our setup we reference one or multiple custom scripts that are uploaded by the pipeline to a storage account ahead of the image deployment.
The scripts are different for the type of OS and hence are also stored in two different folders in the `PipelineAgentsScaleSet` module:

- Linux:    `constructs\azureImageBuilder\scripts\Uploads\linux\LinuxPrepareMachine.ps1`
- Windows:  `constructs\azureImageBuilder\scripts\Uploads\windows\WindowsPrepareMachine.ps1`

One of the main tasks performed by these scripts are the installation of the baseline modules and software we want to have installed on the image. Prime candidates are for example the Az PowerShell modules, Bicep or Terraform.

### Consecutive deployments

After you built your first image, there are a few things to be aware of to operate the pipeline efficiently:

<details>
<summary>Regular cleanup</summary>

You can use the pipeline's checkbox `Pre-remove Image Template Resource Group` at any point with the scope set to `Only removal` to clean your environment up (i.e. remove leftover Image-Templates and AIB resource groups).

</details>

<details>
<summary>Default scope</summary>

Usually, when you will operate the pipeline you would want to either run in scope `Only storage & image` or `Only image`. The first is interesting in case you modified your customization steps and hence want to roll them out. However, if you just want to update your image (for example have it install the latest Bicep version), `Only image` would already be sufficient.

</details>

<details>
<summary>Stacked images</summary>

  Any time you run an image built you first have to decide whether you want to build an image from the ground up (using e.g. a marketplace image as the basis) or build on an existing custom image. In either case you have to configure the image template parameter file in question with regards to the `imageSource` parameter.
  To reference a marketplace image use the syntax:
  ```Bicep
  {
    imageSource: {
      type: 'PlatformImage'
      publisher: 'MicrosoftWindowsDesktop'
      offer: 'Windows-10'
      sku: '19h2-evd'
      version: 'latest'
    }
  }
  ```
  To reference a custom image use the syntax (where the ID is the resourceId of the image version in the Azure Compute Gallery):
  ```Bicep
  {
    imageSource: {
      type: 'SharedImageVersion'
      imageVersionID: '/subscriptions/c64d2kd9-4679-45f5-b17a-e27b0214acp4d/resourceGroups/scale-set-rg/providers/Microsoft.Compute/galleries/mygallery/images/mydefinition/versions/0.24457.34028'
    }
  }
  ```
</details>

# Out of the box installed components

Following you can find an overview of the installed elements currently implemented in the scripts of the `constructs\azureImageBuilder\scripts\Uploads` folder:

| OS |   |   | Windows | Linux |
| -  | - | - | -       | -     |
| Software | `Choco` | | :heavy_check_mark: | |
| | `Azure-CLI` | | :heavy_check_mark: | :heavy_check_mark: |
| | `Bicep-CLI` | | :heavy_check_mark: | :heavy_check_mark: |
| | `PowerShell Core (7.*)` | | :heavy_check_mark: | :heavy_check_mark: |
| | `.NET SDK` | | | :heavy_check_mark: |
| | `.NET Runtime` | | | :heavy_check_mark: |
| | `Nuget Package Provider` | | :heavy_check_mark: | :heavy_check_mark: (`dotnet nuget`) |
| | `Terraform` | | :heavy_check_mark: (`latest`) | :heavy_check_mark: (`0.12.30`)  |
| | `azcopy` | |  :heavy_check_mark: (`latest`) |  :heavy_check_mark: (`latest`) |
| | `docker` | |  :heavy_check_mark: (`latest`) |  :heavy_check_mark: (`latest`) |
| | | | | |
| Modules
| | PowerShell
| | | `PowerShellGet` | :heavy_check_mark: | :heavy_check_mark: |
| | | `Pester` | :heavy_check_mark: | :heavy_check_mark: |
| | | `PSScriptAnalyzer` | :heavy_check_mark: | :heavy_check_mark: |
| | | `powershell-yaml` | :heavy_check_mark: | :heavy_check_mark: |
| | | `Azure.*` | :heavy_check_mark: | :heavy_check_mark: |
| | | `Logging` | :heavy_check_mark: | :heavy_check_mark: |
| | | `PoshRSJob` | :heavy_check_mark: | :heavy_check_mark: |
| | | `ThreadJob` | :heavy_check_mark: | :heavy_check_mark: |
| | | `JWTDetails` | :heavy_check_mark: | :heavy_check_mark: |
| | | `OMSIngestionAPI` | :heavy_check_mark: | :heavy_check_mark: |
| | | `Az` | :heavy_check_mark: | :heavy_check_mark: |
| | | `AzureAD` | :heavy_check_mark: | :heavy_check_mark: |
| | | `ImportExcel` | :heavy_check_mark: | :heavy_check_mark: |
| Extensions
| | CLI
| | | `kubenet` | :heavy_check_mark: | :heavy_check_mark: |
| | | `azure-devops` | :heavy_check_mark: | :heavy_check_mark: |
</details>


# Troubleshooting

Most commonly issues with the construct occur during the image building process due to script errors. As those are hard to troubleshoot and the AIB VMs that are used to bake images are not accessible, the AIB service writes logs into a storage account in the resource group it generates during the building process (`IT_...`) as documented [here](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-troubleshoot#customization-log).

Aside from the packer logs, it will also contain the logs generated by our provided customization scripts and hence provide you insights into 'where' something wrong, and ideally also 'what' went wrong.
