# Microservicios en AKS con Terraform y Docker

Frontend (Nginx) → Backend (FastAPI) → Redis, desplegado en Azure Kubernetes Service.

## 1. Probar en local
```bash
docker compose up --build
# abrir http://localhost:8080 (cada recarga suma una visita)
```

## 2. Crear la infraestructura
```bash
az login
cd terraform
cp terraform.tfvars.example terraform.tfvars   # editar subscription_id y acr_name
terraform init
terraform apply
```

## 3. Publicar imágenes
```bash
ACR=<acr_name>
az acr login --name $ACR
docker build -t $ACR.azurecr.io/backend:v1 ./backend
docker build -t $ACR.azurecr.io/frontend:v1 ./frontend
docker push $ACR.azurecr.io/backend:v1
docker push $ACR.azurecr.io/frontend:v1
```

## 4. Desplegar en Kubernetes
```bash
az aks get-credentials --resource-group microsvc-rg --name microsvc-aks
sed -i "s|ACR_LOGIN_SERVER|$ACR.azurecr.io|" k8s/backend.yaml k8s/frontend.yaml
kubectl apply -f k8s/
kubectl get svc frontend -w     # esperar la EXTERNAL-IP
```

## 5. Destruir (¡siempre al terminar!)
```bash
cd terraform && terraform destroy
```
