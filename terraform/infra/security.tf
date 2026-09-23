# ---------------------------------------------------------------------------
# Группа безопасности кластера.
#
# Без неё узлы получают группу по умолчанию, которая не пропускает входящий
# трафик: балансировщик не проходит проверки здоровья, а снаружи всё отдаёт
# таймаут. Правила — минимально необходимые для работы Managed Kubernetes.
# ---------------------------------------------------------------------------

resource "yandex_vpc_security_group" "k8s" {
  name        = "diplom-k8s-sg"
  description = "Правила для мастера, узлов и балансировщика"
  network_id  = yandex_vpc_network.main.id
  labels      = var.common_labels

  # Проверки состояния от сетевого балансировщика. Диапазоны фиксированы
  # и описаны в документации Yandex Cloud.
  ingress {
    protocol       = "TCP"
    description    = "Проверки состояния балансировщика"
    v4_cidr_blocks = ["198.18.235.0/24", "198.18.248.0/24"]
    from_port      = 0
    to_port        = 65535
  }

  # Трафик внутри кластера: мастер, узлы и поды общаются без ограничений.
  ingress {
    protocol          = "ANY"
    description       = "Обмен внутри кластера"
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    protocol       = "ANY"
    description    = "Трафик подов и сервисов"
    v4_cidr_blocks = [var.cluster_ipv4_range, var.service_ipv4_range]
    from_port      = 0
    to_port        = 65535
  }

  # Публичный доступ на 80 порт — требование задания: Grafana и приложение
  # должны открываться по HTTP.
  ingress {
    protocol       = "TCP"
    description    = "HTTP снаружи"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "HTTPS снаружи"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  # Балансировщик доставляет трафик на NodePort узла, сохраняя адрес клиента,
  # поэтому диапазон портов сервисов должен быть открыт.
  ingress {
    protocol       = "TCP"
    description    = "NodePort для сетевого балансировщика"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 30000
    to_port        = 32767
  }

  # Доступ к API кластера снаружи: kubectl и пайплайн деплоя.
  ingress {
    protocol       = "TCP"
    description    = "Kubernetes API"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  egress {
    protocol       = "ANY"
    description    = "Исходящий трафик без ограничений"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}
