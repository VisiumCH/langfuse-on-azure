---
name: Langfuse on Azure
description: Deploy Langfuse to Azure Container Apps using the Azure Developer CLI.
languages:
- bicep
- azdeveloper
products:
- azure-database-postgresql
- azure-container-apps
- azure
page_type: sample
urlFragment: langfuse-on-azure
---

# Langfuse on Azure

Use the [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/overview) to deploy [Langfuse](https://langfuse.com/) to Azure Container Apps with PostgreSQL Flexible server.

Langfuse is a platform for LLM observability and evaluation. They provide an open-source SDK and containerized web application to receive the SDK's data. This project deploys the Langfuse web application to Azure Container Apps, and uses PostgreSQL to store the data. It also includes a script to set up Entra-based authentication for the web app. Once you have deployed Langfuse, you can integrate the SDK into your LLM applications according to the [Langfuse documentation](https://langfuse.com/docs/) and start sending data to the web app.

Table of contents:

* [Opening this project](#opening-this-project)
  * [GitHub Codespaces](#github-codespaces)
  * [VS Code Dev Containers](#vs-code-dev-containers)
  * [Local environment](#local-environment)
* [Deploying to Azure](#deploying-to-azure)
* [Disclaimer](#disclaimer)

## Opening this project

You have a few options for setting up this project.
The easiest way to get started is GitHub Codespaces, since it will setup all the tools for you,
but you can also [set it up locally](#local-environment) if desired.

### GitHub Codespaces

You can run this repo virtually by using GitHub Codespaces, which will open a web-based VS Code in your browser:

[![Open in GitHub Codespaces](https://img.shields.io/static/v1?style=for-the-badge&label=GitHub+Codespaces&message=Open&color=brightgreen&logo=github)](https://codespaces.new/Azure-Samples/langfuse-on-azure)

Once the codespace opens (this may take several minutes), open a terminal window.

### VS Code Dev Containers

A related option is VS Code Dev Containers, which will open the project in your local VS Code using the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers):

1. Start Docker Desktop (install it if not already installed)
1. Open the project:
    [![Open in Dev Containers](https://img.shields.io/static/v1?style=for-the-badge&label=Dev%20Containers&message=Open&color=blue&logo=visualstudiocode)](https://vscode.dev/redirect?url=vscode://ms-vscode-remote.remote-containers/cloneInVolume?url=https://github.com/azure-samples/langfuse-on-azure)
1. In the VS Code window that opens, once the project files show up (this may take several minutes), open a terminal window.

### Local environment

1. Install the required tools:

    * [Azure Developer CLI](https://aka.ms/azure-dev/install)
    * [Python 3.9, 3.10, or 3.11](https://www.python.org/downloads/) (Only necessary if you want to enable authentication via script)

2. Clone this repository

4. Create a Python virtual environment and install the required package. We use pipenv and the required packages are defined in the Pipfile and Pipfile.lock in the root directory. If the user prefers using venv, the requirements.txt file is found in the root.

    ```shell
    pipenv install
    pipenv shell
    ```



## Deploying to Azure

Follow these steps to deploy Langfuse to Azure:

1. Login to your Azure account:

    ```shell
    azd auth login
    ```

2. Create a new azd environment:

    ```shell
    azd env new <env-name>
    ```

    This will create a new folder in the `.azure` folder, and set it as the active environment for any calls to `azd` going forward.

3. (Optional) By default, the deployed Azure Container App will use the Langfuse authentication system, meaning anyone with routable network access to the web app can attempt to login to it. To enable Entra-based authentication, set the `AZURE_USE_AUTHENTICATION` environment variable to `true`:

    ```shell
    azd env set AZURE_USE_AUTHENTICATION true
    ```

    Then set the `AZURE_AUTH_TENANT_ID` environment variable to your tenant ID:

    ```shell
    azd env set AZURE_AUTH_TENANT_ID your-tenant-id
    ```

    To disable username and password as authentication method, set the `AUTH_DISABLE_USERNAME_PASSWORD` environment variable to `true`

    ```shell
    azd env set AUTH_DISABLE_USERNAME_PASSWORD true
    ```

    > ⚠️ **IMPORTANT:** Azure authentication requires app registration. If the `AZURE_USE_AUTHENTICATION` environment variable is set to `true`, the deployment will use the `auth_init.sh` and `auth_update.sh` hooks to set up the necessary resources for Entra-based authentication, including app registration, and pass the necessary environment variables to the Azure Container App. If script-based app registration is not allowed, deploy the resources with `AZURE_USE_AUTHENTICATION` set to `false` and change it manually after deployment.


4. Run this command to provision all the resources:

    ```shell
    azd provision
    ```

    This will create a new resource group, and create the Azure Container App and PostgreSQL Flexible server inside that group.
    If you enabled authentication, it will use the `auth_init.sh` and `auth_update.sh` hooks to set up the necessary resources for Entra-based authentication, and pass the necessary environment variables to the Azure Container App.

4. Once the deployment is complete, you will see the URL for the Azure Container App in the output. You can open this URL in your browser to see the Langfuse web app.

## (Optional) Azure Authentication

If at deployment the default Langfuse username/password authentication was selected, you can change it to Azure authentication manually.

1. Manual App registration
2. Manually add secrets to the Container App:
    - Navigate to the Azure Portal
    - Select the deployed Container App
    - Navigate to Settings -> Secrets
    - Update the `authclientsecret`
3. Manually add requireed environment variables to the Container App:
    - Navigate to Application -> Revisions and Replicas
    - Select `Create new revision`
    - Select the container image and `Edit`
    - Select the `Environment variables` Tab.
    - Add (or Edit if already existing) `AUTH_AZURE_AD_TENANT_ID`, Source=`Manual entry`, Value=`<your-tenant-id>`
    - Add (or Edit if already existing) `AUTH_AZURE_AD_CLIENT_ID`, Source=`Manual entry`, Value=`<your-client-id>`
    - Add (or Edit if already existing) `AUTH_AZURE_AD_CLIENT_SECRET`, Source=`Reference a secret`, Value=`authclientsecret`


## (Optional) Langfuse Customization

The Langfuse deployment can also be partly customized through the usage of environment variables. The user can find the list of environment variables in the [official documentation](https://langfuse.com/self-hosting/v2/deployment-guide).

> ⚠️ **IMPORTANT:** The Langfuse image that is deployed is the Version 2 of the Langfuse software. A later version (V3) has been released in December 2024, however as of now (February 2025) the latest version cannot yet be easily self-hosted in Azure.

> ⚠️ **IMPORTANT:** The default deployment is for the Free version of the self-hosted Langfuse. Langfuse allows additional customizations under the Enterprise Edition.
