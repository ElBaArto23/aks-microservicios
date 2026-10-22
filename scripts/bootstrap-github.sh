#!/usr/bin/env bash
# Preparación ÚNICA para GitHub Actions. Ejecutar en Azure Cloud Shell (Bash).
# Crea: (1) una cuenta de almacenamiento para el estado de Terraform y
#       (2) un service principal para que GitHub pueda actuar en tu suscripción.
# Imprime los secretos y variables que debes guardar en el repositorio de GitHub.
set -euo pipefail

LOCATION="${LOCATION:-eastus}"
TFSTATE_RG="tfstate-rg"
TFSTATE_SA="tfstate$(openssl rand -hex 4)"
SP_NAME="aks-microservicios-gh"

SUB="$(az account show --query id -o tsv)"
TENANT="$(az account show --query tenantId -o tsv)"

echo "==> Almacenamiento para el estado de Terraform"
az group create --name "$TFSTATE_RG" --location "$LOCATION" -o none
az storage account create --name "$TFSTATE_SA" --resource-group "$TFSTATE_RG" \
  --location "$LOCATION" --sku Standard_LRS --min-tls-version TLS1_2 \
  --allow-blob-public-access false -o none
az storage container create --name tfstate --account-name "$TFSTATE_SA" --auth-mode key -o none

echo "==> Service principal $SP_NAME"
# Contributor crea los recursos; User Access Administrator permite el rol AcrPull de Terraform.
SP_JSON="$(az ad sp create-for-rbac --name "$SP_NAME" --role Contributor \
  --scopes "/subscriptions/$SUB" -o json)"
CLIENT_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["appId"])' <<<"$SP_JSON")"
CLIENT_SECRET="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["password"])' <<<"$SP_JSON")"
az role assignment create --assignee "$CLIENT_ID" --role "User Access Administrator" \
  --scope "/subscriptions/$SUB" -o none

cat <<OUT

=====================================================================
GitHub -> tu repo -> Settings -> Secrets and variables -> Actions

[Secrets]  (pestaña "Secrets", New repository secret)
  AZURE_CLIENT_ID        = $CLIENT_ID
  AZURE_CLIENT_SECRET    = $CLIENT_SECRET
  AZURE_TENANT_ID        = $TENANT
  AZURE_SUBSCRIPTION_ID  = $SUB

[Variables]  (pestaña "Variables", New repository variable)
  TFSTATE_RG             = $TFSTATE_RG
  TFSTATE_SA             = $TFSTATE_SA
  ACR_NAME               = <tu nombre de ACR, p. ej. jacjson23ac>
=====================================================================
El AZURE_CLIENT_SECRET solo se muestra ahora. No lo compartas ni lo subas al repo.
OUT
