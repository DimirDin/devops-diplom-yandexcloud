# ---------------------------------------------------------------------------
# Сервисный аккаунт для Terraform.
#
# Права выдаются точечно, по принципу необходимого и достаточного:
# роль editor/admin на каталог сознательно НЕ используется.
# ---------------------------------------------------------------------------

resource "yandex_iam_service_account" "terraform" {
  name        = var.sa_name
  description = "Сервисный аккаунт для управления инфраструктурой из Terraform"
  folder_id   = var.folder_id
}

locals {
  # Минимальный набор ролей под задачи основного конфига:
  # сеть, managed k8s, реестр образов, объектное хранилище под стейт.
  terraform_sa_roles = [
    "vpc.admin",                # сети и подсети
    "k8s.admin",                # кластер Managed Kubernetes
    "k8s.clusters.agent",       # работа кластера от имени SA
    "container-registry.admin", # Container Registry
    "compute.admin",            # узлы группы узлов
    "iam.serviceAccounts.user", # назначать SA узлам кластера
    "storage.editor",           # чтение/запись стейта в бакете
    "load-balancer.admin",      # балансировщики, создаваемые ingress-ом
  ]
}

resource "yandex_resourcemanager_folder_iam_member" "terraform" {
  for_each = toset(local.terraform_sa_roles)

  folder_id = var.folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.terraform.id}"
}

# ---------------------------------------------------------------------------
# Статический ключ доступа — им Terraform ходит в S3-совместимое хранилище.
# ---------------------------------------------------------------------------

resource "yandex_iam_service_account_static_access_key" "terraform" {
  service_account_id = yandex_iam_service_account.terraform.id
  description        = "Ключ доступа к Object Storage для backend Terraform"
}

# ---------------------------------------------------------------------------
# Бакет под стейт основной инфраструктуры.
# ---------------------------------------------------------------------------

resource "yandex_storage_bucket" "tfstate" {
  bucket     = var.state_bucket_name
  access_key = yandex_iam_service_account_static_access_key.terraform.access_key
  secret_key = yandex_iam_service_account_static_access_key.terraform.secret_key

  # Стейт содержит чувствительные данные — публичного доступа быть не должно.
  anonymous_access_flags {
    read        = false
    list        = false
    config_read = false
  }

  # Версионирование спасает при повреждении стейта или ошибочном apply.
  versioning {
    enabled = true
  }

  # Бакет со стейтом не должен уезжать вместе с случайным destroy.
  lifecycle {
    prevent_destroy = true
  }

  depends_on = [yandex_resourcemanager_folder_iam_member.terraform]
}

# ---------------------------------------------------------------------------
# Сервисные аккаунты для самого кластера.
#
# Живут здесь, а не в infra, по двум причинам:
#   1) создание сервисных аккаунтов требует прав уровня iam.serviceAccounts.admin,
#      выдавать которые Terraform-аккаунту не хочется;
#   2) terraform destroy в infra не должен ронять IAM-обвязку.
# ---------------------------------------------------------------------------

resource "yandex_iam_service_account" "k8s_cluster" {
  name        = "k8s-cluster-sa"
  description = "SA мастера Managed Kubernetes: сеть, диски, балансировщики"
  folder_id   = var.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_cluster" {
  for_each = toset([
    "k8s.clusters.agent",
    "vpc.publicAdmin",
    "load-balancer.admin",
  ])

  folder_id = var.folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.k8s_cluster.id}"
}

resource "yandex_iam_service_account" "k8s_node" {
  name        = "k8s-node-sa"
  description = "SA узлов кластера: только загрузка образов из Container Registry"
  folder_id   = var.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_node" {
  folder_id = var.folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_node.id}"
}
