#!/usr/bin/env bash
# Destruye toda la infraestructura para dejar de consumir crédito.
# Uso: ./scripts/down.sh        (pide confirmación)
#      ./scripts/down.sh -y     (sin confirmación)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RG="microsvc-rg"

if [ "${1:-}" != "-y" ]; then
  read -r -p "Esto destruye el grupo de recursos '$RG' y todo su contenido. ¿Continuar? [s/N] " ans
  [[ "$ans" =~ ^[sSyY]$ ]] || { echo "Cancelado."; exit 0; }
fi

cd "$ROOT/terraform"
if terraform destroy -auto-approve -input=false; then
  echo "==> terraform destroy terminado"
else
  echo "==> terraform destroy falló (¿bloqueo de estado?); borrando el grupo con az" >&2
  az group delete --name "$RG" --yes
  rm -f terraform.tfstate terraform.tfstate.backup .terraform.tfstate.lock.info
fi

echo "==> Verificando"
for _ in $(seq 1 30); do
  if [ "$(az group exists --name "$RG")" = "false" ]; then
    echo "OK: '$RG' ya no existe. No hay cobros de este proyecto."
    exit 0
  fi
  sleep 10
done
echo "El grupo '$RG' todavía existe; revisa en el portal." >&2
exit 1
