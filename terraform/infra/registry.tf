# ---------------------------------------------------------------------------
# Container Registry под образы тестового приложения.
# Права на pull выданы SA узлов в terraform/bootstrap.
# ---------------------------------------------------------------------------

resource "yandex_container_registry" "main" {
  name      = var.registry_name
  folder_id = var.folder_id
}
