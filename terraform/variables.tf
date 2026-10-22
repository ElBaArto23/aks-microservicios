variable "subscription_id" {
  description = "ID de la suscripción de Azure"
  type        = string
}

variable "location" {
  description = "Región de Azure"
  type        = string
  default     = "eastus"
}

variable "prefix" {
  description = "Prefijo para nombrar los recursos"
  type        = string
  default     = "microsvc"
}

variable "acr_name" {
  description = "Nombre único global del ACR (solo minúsculas y números)"
  type        = string
}

variable "node_vm_size" {
  description = "Tamaño de la VM del nodo"
  type        = string
  default     = "Standard_B2s"
}
