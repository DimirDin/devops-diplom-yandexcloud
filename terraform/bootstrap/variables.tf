variable "cloud_id" {
  description = "Идентификатор облака Yandex Cloud"
  type        = string
}

variable "folder_id" {
  description = "Идентификатор каталога, в котором создаётся вся инфраструктура"
  type        = string
}

variable "default_zone" {
  description = "Зона доступности по умолчанию"
  type        = string
  default     = "ru-central1-a"
}

variable "sa_name" {
  description = "Имя сервисного аккаунта, от имени которого работает Terraform"
  type        = string
  default     = "terraform-sa"
}

variable "state_bucket_name" {
  description = "Имя S3-бакета для хранения стейта основной инфраструктуры (глобально уникально)"
  type        = string
}
