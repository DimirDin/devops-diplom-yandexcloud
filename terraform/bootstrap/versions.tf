terraform {
  required_version = ">= 1.5.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.130"
    }
  }

  # Стейт бутстрапа намеренно остаётся локальным: этот код создаёт сам бакет,
  # в котором лежит стейт основной инфраструктуры. Класть его в собственный
  # бакет нельзя — курица и яйцо, плюс terraform destroy в infra не должен
  # иметь возможности задеть хранилище стейтов.
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.default_zone
}
