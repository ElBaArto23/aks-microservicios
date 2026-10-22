#!/usr/bin/env bash
# Levanta la infraestructura y despliega la app. Ejecutar en Azure Cloud Shell (Bash).
# Uso: ./scripts/up.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/terraform"

echo "==> Terraform: init + apply"
terraform init -input=false
terraform apply -auto-approve -input=false

RG="$(terraform output -raw resource_group)"
AKS="$(terraform output -raw aks_name)"
ACR_SERVER="$(terraform output -raw acr_login_server)"
ACR_NAME="${ACR_SERVER%%.*}"

echo "==> Comprobando imágenes en $ACR_NAME"
REPOS="$(az acr repository list --name "$ACR_NAME" -o tsv 2>/dev/null || true)"
if ! grep -qx backend <<<"$REPOS" || ! grep -qx frontend <<<"$REPOS"; then
  echo "==> Faltan imágenes; intentando az acr build"
  if ! { az acr build --registry "$ACR_NAME" --image backend:v1 "$ROOT/backend" &&
         az acr build --registry "$ACR_NAME" --image frontend:v1 "$ROOT/frontend"; }; then
    cat >&2 <<MSG

ACR Tasks no está disponible en esta suscripción. Construye y sube las imágenes
desde un entorno con Docker (por ejemplo Codespaces):

  1) Aquí, en Cloud Shell:
     az acr login --name $ACR_NAME --expose-token --output tsv --query accessToken
  2) En Codespaces:
     docker login $ACR_SERVER --username 00000000-0000-0000-0000-000000000000 --password '<TOKEN>'
     ./scripts/push-images.sh $ACR_SERVER

Después vuelve a ejecutar ./scripts/up.sh (la infraestructura ya existe, es idempotente).
MSG
    exit 1
  fi
fi

echo "==> Conectando kubectl a $AKS"
az aks get-credentials --resource-group "$RG" --name "$AKS" --overwrite-existing

echo "==> Desplegando manifiestos"
cd "$ROOT"
for f in k8s/*.yaml; do
  sed "s|ACR_LOGIN_SERVER|$ACR_SERVER|g" "$f"
  echo "---"
done | kubectl apply -f -

kubectl rollout status deployment/redis --timeout=180s
kubectl rollout status deployment/backend --timeout=180s
kubectl rollout status deployment/frontend --timeout=180s

echo "==> Esperando IP pública"
for _ in $(seq 1 60); do
  IP="$(kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  [ -n "$IP" ] && break
  sleep 5
done

if [ -n "${IP:-}" ]; then
  echo
  echo "Listo: http://$IP"
else
  echo "Aún sin IP; revisa con: kubectl get svc frontend -w" >&2
fi
echo "Recuerda apagar todo al terminar: ./scripts/down.sh"
