# Microservicios en AKS con Terraform y Docker

Frontend (Nginx) → Backend (FastAPI) → Redis, desplegado en Azure Kubernetes Service.

## Costo aproximado
Con `Standard_D2as_v4` + ACR Basic + balanceador: ~US$0.10 por hora (~US$70–90 al mes).
**Destruye todo al terminar** (paso 6).

## Opción CI/CD: GitHub Actions (sin Docker local ni Codespaces)
Los runners de GitHub traen Docker, así que construyen y suben las imágenes solos.

**Preparación única** (Cloud Shell):
```bash
./scripts/bootstrap-github.sh
```
Imprime 4 *secrets* y 3 *variables* para guardar en GitHub
(Settings → Secrets and variables → Actions). Pon tu nombre de ACR en `ACR_NAME`.

**Uso:** pestaña *Actions* del repo.
- **Deploy** (Run workflow): Terraform + imágenes + despliegue; la IP queda en el resumen de la ejecución.
- **Destroy** (Run workflow): apaga todo. También corre cada noche a las 03:00 UTC como red de seguridad
  (desactívalo con la variable de repositorio `AUTO_DESTROY = false`).

El estado de Terraform vive en Azure Storage (`tfstate-rg`). No mezcles este flujo con
`scripts/up.sh`: cada uno lleva su propio estado.

## Atajo: scripts (Cloud Shell)
```bash
./scripts/up.sh      # terraform apply + imágenes + kubectl apply + muestra la IP
./scripts/down.sh    # terraform destroy + verifica que el grupo ya no exista
```
`up.sh` intenta `az acr build`; si ACR Tasks está bloqueado, te indica cómo subir las imágenes
con `./scripts/push-images.sh <acr>.azurecr.io` desde Codespaces. Los pasos 2–6 siguientes son el detalle manual.

## 1. Probar en local
```bash
docker compose up --build
# http://localhost:8080 (cada recarga suma una visita)
```
En GitHub Codespaces la red entre contenedores está bloqueada; usa en su lugar:
```bash
docker compose -f docker-compose.codespaces.yml up --build
# Abrir el puerto 80 (añadirlo a mano en la pestaña Ports si no aparece)
```

## 2. Crear la infraestructura (Azure Cloud Shell, Bash)
```bash
git clone https://github.com/<usuario>/aks-microservicios.git
cd aks-microservicios/terraform
cp terraform.tfvars.example terraform.tfvars   # editar subscription_id y acr_name
az account show --query id -o tsv              # subscription_id
terraform init
terraform validate
terraform plan
terraform apply
```
Si tu suscripción rechaza el tamaño de VM, cambia `node_vm_size` en `terraform.tfvars`
(el error lista los tamaños permitidos).

## 3. Publicar imágenes
Intenta primero `az acr build` (no requiere Docker):
```bash
ACR=<acr_name>
az acr build --registry $ACR --image backend:v1 ./backend
az acr build --registry $ACR --image frontend:v1 ./frontend
```
Si da `TasksOperationsNotAllowed` (ACR Tasks bloqueado en cuentas gratuitas), construye
con Docker desde **Codespaces** (Cloud Shell no tiene daemon de Docker):

1. En Cloud Shell, genera un token temporal (~3 h, tratarlo como contraseña):
   ```bash
   az acr login --name $ACR --expose-token --output tsv --query accessToken
   ```
2. En el Codespace:
   ```bash
   docker login $ACR.azurecr.io --username 00000000-0000-0000-0000-000000000000 --password '<TOKEN>'
   docker build -t $ACR.azurecr.io/backend:v1 ./backend
   docker build -t $ACR.azurecr.io/frontend:v1 ./frontend
   docker push $ACR.azurecr.io/backend:v1
   docker push $ACR.azurecr.io/frontend:v1
   ```
3. Verifica en Cloud Shell: `az acr repository list --name $ACR -o table`

## 4. Desplegar en Kubernetes (Cloud Shell)
```bash
az aks get-credentials --resource-group microsvc-rg --name microsvc-aks
sed -i "s|ACR_LOGIN_SERVER|$ACR.azurecr.io|" k8s/backend.yaml k8s/frontend.yaml
kubectl apply -f k8s/
kubectl get pods
kubectl get svc frontend -w     # esperar la EXTERNAL-IP y abrir http://<IP>
```

## 5. Diagnóstico rápido
```bash
kubectl get pods
kubectl logs <pod>
kubectl describe pod <pod>
```
Nota: Kubernetes inyecta variables como `REDIS_PORT=tcp://...` por cada Service. Por eso
`k8s/backend.yaml` fija `REDIS_PORT: "6379"` de forma explícita.

## 6. Destruir (¡siempre al terminar!)
```bash
cd terraform && terraform destroy
az group exists --name microsvc-rg     # debe responder false
```
Si `terraform destroy` falla por un bloqueo de estado tras una desconexión:
```bash
az group delete --name microsvc-rg --yes --no-wait
rm -f terraform.tfstate terraform.tfstate.backup .terraform.tfstate.lock.info
```
