output "cluster_id" {
  description = "ID кластера Kubernetes"
  value       = yandex_kubernetes_cluster.main.id
}

output "cluster_name" {
  description = "Имя кластера Kubernetes"
  value       = yandex_kubernetes_cluster.main.name
}

output "cluster_external_endpoint" {
  description = "Внешний endpoint мастера"
  value       = yandex_kubernetes_cluster.main.master[0].external_v4_endpoint
}

output "registry_id" {
  description = "ID Container Registry — часть пути к образу"
  value       = yandex_container_registry.main.id
}

output "image_repository" {
  description = "Базовый путь для docker push"
  value       = "cr.yandex/${yandex_container_registry.main.id}"
}

output "kubeconfig_command" {
  description = "Команда для получения ~/.kube/config"
  value       = "yc managed-kubernetes cluster get-credentials --id ${yandex_kubernetes_cluster.main.id} --external --force"
}
