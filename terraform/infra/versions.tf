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
    # endpoint, а не endpoints: блочный синтаксис появился только в Terraform 1.6,
    # а на машине 1.5.7 — там он молча игнорируется и бэкенд уходит в AWS.
    # Этот вариант понимают обе версии.
    endpoint = "https://storage.yandexcloud.net"
    region   = "ru-central1"

    # Yandex Object Storage — S3-совместимое, но не AWS:
    # проверки, специфичные для AWS, отключаем.
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    force_path_style            = true
  }
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zones[0]
}
