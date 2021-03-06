#!/bin/bash

export RG=$1
export location=$2
export functionAppName=$3
export storageName=$4
export aesKey=$5
export aesIV=$6
export passwordVaultID=$7
export passwordVaultUrl=$8
export passwordVaultCode=$9
export clientID=${10}
export clientSecret=${11}
export RESOURCE_GROUP_NAME=${12}
export COSMOS_DB_ACCOUNT=${13}
export FUNCTION_ACCOUNT=${14}

#az login 
az extension add --name webapp
az extension add --name storage-preview

if ! `az group exists -g $RG`; then az group create -n $RG -l $location; fi

funcStorageName=${functionAppName}sa001
keyVaultName=${functionAppName}keyvault001

# Create an Azure Function with storage accouunt in the resource group.
if ! `az functionapp show --name $functionAppName --resource-group $RG -o none`
then
    az storage account create --name $funcStorageName --location $location --resource-group $RG --sku Standard_LRS
    az functionapp create --name $functionAppName --storage-account $funcStorageName --consumption-plan-location $location --resource-group $RG --os-type Linux --functions-version 3 --runtime python
    az functionapp identity assign --name $functionAppName --resource-group $RG
fi
functionAppId="$(az functionapp identity show --name $functionAppName --resource-group $RG --query 'principalId' --output tsv)"

# Create an storage accouunt in the resource group the backups
az storage account create --kind StorageV2 --name $storageName --location $location --resource-group $RG --sku Standard_LRS
key=$(az storage account keys list -n $storageName --query "[0].value" -o tsv)
az storage container create --name 'backups' --account-key $key --account-name $storageName

# Create Key Vault 
az keyvault create --name $keyVaultName --resource-group $RG --location $location 
az keyvault set-policy --name $keyVaultName --object-id $functionAppId --secret-permissions get

clientSecretId="$(az keyvault secret set --vault-name $keyVaultName --name clientSecret --value $clientSecret --query 'id' --output tsv)"
aesKeySecretId="$(az keyvault secret set --vault-name $keyVaultName --name AesKey  --value $aesKey --query 'id' --output tsv)"
funcCodeId="$(az keyvault secret set --vault-name $keyVaultName --name passwordVaultCode --value $passwordVaultCode --query 'id' --output tsv)"

tenant=`az account  show --query tenantId -o tsv`
subId=`az account  show --query id -o tsv`
loginUrl="https://login.microsoftonline.com/${tenant}/oauth2/token"
passwordStorageConString="DefaultEndpointsProtocol=https;AccountName=${storageName};AccountKey=${key};EndpointSuffix=core.windows.net"

az functionapp config appsettings set -g $RG -n $functionAppName --settings SpnSecret="@Microsoft.KeyVault(SecretUri=$clientSecretId)"
az functionapp config appsettings set -g $RG -n $functionAppName --settings AesKey="@Microsoft.KeyVault(SecretUri=$aesKeySecretId)"
az functionapp config appsettings set -g $RG -n $functionAppName --settings FunctionCode="@Microsoft.KeyVault(SecretUri=$funcCodeId)"
az functionapp config appsettings set -g $RG -n $functionAppName --settings AesIV=$aesIV
az functionapp config appsettings set -g $RG -n $functionAppName --settings PasswordStorage=$passwordStorageConString
az functionapp config appsettings set -g $RG -n $functionAppName --settings Clientid=$clientID
az functionapp config appsettings set -g $RG -n $functionAppName --settings VaultSpnId=$passwordVaultID
az functionapp config appsettings set -g $RG -n $functionAppName --settings AppUrl=$passwordVaultUrl
az functionapp config appsettings set -g $RG -n $functionAppName --settings LoginUrl=$loginUrl
az functionapp config appsettings set -g $RG -n $functionAppName --settings SUBSCRIPTION_ID=$subId
az functionapp config appsettings set -g $RG -n $functionAppName --settings RESOURCE_GROUP_NAME=${RESOURCE_GROUP_NAME}
az functionapp config appsettings set -g $RG -n $functionAppName --settings COSMOS_DB_ACCOUNT=${COSMOS_DB_ACCOUNT}
az functionapp config appsettings set -g $RG -n $functionAppName --settings FUNCTION_ACCOUNT=${FUNCTION_ACCOUNT}
az functionapp config appsettings set -g $RG -n $functionAppName --settings KEY_VAULT_URL=${KEY_VAULT_URL}
