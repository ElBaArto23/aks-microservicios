#!/usr/bin/env bash
# Construye y sube las imágenes al ACR. Ejecutar donde haya Docker (p. ej. Codespaces),
# después de hacer `docker login` contra el ACR (ver README, paso 3).
# Uso: ./scripts/push-images.sh <acr>.azurecr.io [tag]
set -euo pipefail

ACR_SERVER="${1:?Uso: $0 <acr>.azurecr.io [tag]}"
TAG="${2:-v1}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for svc in backend frontend; do
  docker build -t "$ACR_SERVER/$svc:$TAG" "$ROOT/$svc"
  docker push "$ACR_SERVER/$svc:$TAG"
done
