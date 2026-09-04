terraform {
  required_version = ">= 1.5.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.130"
    }
  }

  # Стейт лежит в бакете, созданном в terraform/bootstrap.
  # Значения подставляются из backend.hcl:
  #   terraform init -backend-config=backend.hcl
  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    region = "ru-central1"

    # Yandex Object Storage — S3-совместимое, но не AWS:
    # проверки, специфичные для AWS, отключаем.
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zones[0]
}
