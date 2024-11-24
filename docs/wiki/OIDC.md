This section gives you an overview of how to set up a managed identity and use it for an OIDC-based service connection in Azure DevOPs

### _Navigation_
- [Create Service Connection (Part 1)](#create-service-connection-part-1)
- [Create managed identity](#create-managed-identity)
- [Create federated credential](#create-federated-credential)
- [Create Service Connection (Part 2)](#create-service-connection-part-2)

# Create Service Connection (Part 1)

1. To start the setup, navigate to the 'Service connections' of your 'Project Settings' and select 'New service connection'

   <img src="./media/oidc/serviceConnection-init.png" alt="Init service connection" height="400">

1. Next, select 'Azure Resource Manager' as the service connection type and click on 'Next'

   <img src="./media/oidc/serviceConnection-type.png" alt="Select service connection type" height="400">

1. When asked which type of authentication you'd like to use, select 'Workload Identity Federation (manual)'

   <img src="./media/oidc/serviceConnection-authentication.png" alt="Select service connection authentication" height="400">

1. Finally, give the to-be service connection a name, and select 'Next' one last time (for now)

   <img src="./media/oidc/serviceConnection-name.png" alt="Select service connection name" height="400">

1. In this following view, take not of the 'Issuer' & 'Subject identifier' values. You'll need those to create the federated credential

   <img src="./media/oidc/serviceConnection-issuer.png" alt="Select service connection issuer info" height="400">

# Create managed identity

With the service connection prepared, we can now move on the the Managed Identity in Azure

1. To start, navigate to the Managed Identity overview and select '+ Create'

   <img src="./media/oidc/managedIdentityCreate.png" alt="Init MSI creation" height="400">

1. Next, provide the required information like the resource group, name & location and initialize the creation by selecting the 'Review + create', followed by another click on the 'Create' button

   <img src="./media/oidc/managedIdentityDetails.png" alt="MSI details" height="400">

1. Once the resource is created, navigate to it so that we can start creating the federated credential

# Create federated credential

1. On the managed identity resource, select 'Federated credentials' in the resource blade, followed by '+ Add Credential'

   <img src="./media/oidc/credentialInit.png" alt="Init credential" height="400">

1. Now, for the
   - 'Federated credential scenario', select '**Other** Configure an identity managed by an external OpenID Connect Provider to access Azure resources as this application'
   - 'Issuer Url' provide the 'Issuer' value from the last step in the preceding Service Connection creation.
   - 'Subject identifier' provide the 'Subject identifier' value from the last step in the preceding Service Connection creation.
   - Name, a name of your choice

   <img src="./media/oidc/credentialDetails.png" alt="Credential details" height="400">

1. Finally, finish the creation of the Federated Credential by selecting 'Add'

# Create Service Connection (Part 2)


