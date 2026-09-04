output "service_account_id" {
  description = "ID сервисного аккаунта Terraform"
  value       = yandex_iam_service_account.terraform.id
}

output "state_bucket" {
  description = "Имя бакета со стейтом основной инфраструктуры"
  value       = yandex_storage_bucket.tfstate.bucket
}

output "access_key" {
  description = "Access key для backend'а (подставить в AWS_ACCESS_KEY_ID)"
  value       = yandex_iam_service_account_static_access_key.terraform.access_key
  sensitive   = true
}

output "secret_key" {
  description = "Secret key для backend'а (подставить в AWS_SECRET_ACCESS_KEY)"
  value       = yandex_iam_service_account_static_access_key.terraform.secret_key
  sensitive   = true
}

output "k8s_cluster_sa_id" {
  description = "ID сервисного аккаунта мастера кластера"
  value       = yandex_iam_service_account.k8s_cluster.id
}

output "k8s_node_sa_id" {
  description = "ID сервисного аккаунта узлов кластера"
  value       = yandex_iam_service_account.k8s_node.id
}
