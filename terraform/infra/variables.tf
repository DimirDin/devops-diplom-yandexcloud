variable "cloud_id" {
  description = "Идентификатор облака Yandex Cloud"
  type        = string
}

variable "folder_id" {
  description = "Идентификатор каталога"
  type        = string
}

variable "zones" {
  description = "Зоны доступности под подсети и региональный мастер"
  type        = list(string)
  default     = ["ru-central1-a", "ru-central1-b", "ru-central1-d"]
}

variable "subnet_cidrs" {
  description = "CIDR подсетей, по одной на зону из var.zones"
  type        = list(string)
  default     = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]

  validation {
    condition     = length(var.subnet_cidrs) == 3
    error_message = "Нужно ровно три подсети — по одной на зону регионального мастера."
  }
}

variable "cluster_ipv4_range" {
  description = "Диапазон адресов подов"
  type        = string
  default     = "10.112.0.0/16"
}

variable "service_ipv4_range" {
  description = "Диапазон адресов сервисов"
  type        = string
  default     = "10.96.0.0/16"
}

variable "k8s_version" {
  description = "Версия Kubernetes"
  type        = string
  default     = "1.30"
}

variable "k8s_cluster_sa_id" {
  description = "ID сервисного аккаунта мастера (output из terraform/bootstrap)"
  type        = string
}

variable "k8s_node_sa_id" {
  description = "ID сервисного аккаунта узлов (output из terraform/bootstrap)"
  type        = string
}

variable "node_count" {
  description = "Количество рабочих узлов"
  type        = number
  default     = 2
}

variable "node_cores" {
  description = "vCPU на узел"
  type        = number
  default     = 2
}

variable "node_memory" {
  description = "Память узла, ГБ"
  type        = number
  default     = 4
}

variable "node_core_fraction" {
  description = "Гарантированная доля vCPU, % (20 — самый дешёвый вариант)"
  type        = number
  default     = 20
}

variable "node_disk_size" {
  description = "Размер диска узла, ГБ"
  type        = number
  default     = 32
}

variable "node_preemptible" {
  description = "Прерываемые узлы: заметно дешевле, живут не дольше 24 часов"
  type        = bool
  default     = true
}

variable "registry_name" {
  description = "Имя Container Registry для образов тестового приложения"
  type        = string
  default     = "diplom-registry"
}
