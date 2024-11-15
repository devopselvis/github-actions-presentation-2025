#!/bin/bash

# This script deploys a Bicep template to create a resource group and then creates an Azure AD App registration.
# Usage: ./deploy.sh <resource-group-name> <location> <app-name>

# Check if the correct number of arguments are passed
if [ "$#" -ne 8 ]; then
    echo "Usage: $0 <subscriptionid> <resource-group-name> <location> <ad-app-name> <org> <repo> <branch> <webappname>"
    exit 1
fi

# Parameters
subscriptionId=$1
resourceGroupName=$2
location=$3
adAppName=$4
org=$5
repo=$6
branch=$7
webAppName=$8


# Deploy the Bicep template to create the resource group
echo "Deploying Bicep template to create resource group..."
az deployment sub create --location $location --template-file main.bicep --parameters resourceGroupName=$resourceGroupName location=$location webappname=$webAppName
# Check if the deployment was successful
if [ $? -ne 0 ]; then
    echo "Failed to deploy the Bicep template."
    exit 1
fi

# Create the Azure AD App registration
echo "Creating Azure AD App registration..."
appId=$(az ad app create --display-name $adAppName --query appId --output tsv)

# Check if the app registration was successful
if [ $? -ne 0 ]; then
    echo "Failed to create Azure AD App registration."
    exit 1
fi

# Create the service principal for the Azure AD App
echo "Creating service principal for the Azure AD App..."
az ad sp create --id $appId

# Check if the service principal creation was successful
if [ $? -ne 0 ]; then
    echo "Failed to create service principal."
    exit 1
fi

# Create a new federated credential for GitHub Actions
echo "Creating federated credential..."
az ad app federated-credential create --id $appId --parameters '{
  "name": "github-actions-presentation-2025-cred1",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:'$org'/'$repo':ref:refs/heads/'$branch'",
  "audiences": ["api://AzureADTokenExchange"]
}'

# Check if the federated credential creation was successful
if [ $? -ne 0 ]; then
    echo "Failed to create federated credential."
    exit 1
fi

# Assign Contributor role to the Azure AD App for the resource group
echo "Assigning Contributor role to the Azure AD App for the resource group..."
az role assignment create --assignee $appId --role Contributor --scope /subscriptions/$subscriptionId/resourceGroups/$resourceGroupName

# Check if the role assignment was successful
if [ $? -ne 0 ]; then
    echo "Failed to assign Contributor role."
    exit 1
fi

echo "Deployment, Azure AD App registration, federated credential creation, and role assignment completed successfully."