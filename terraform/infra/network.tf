# ---------------------------------------------------------------------------
# Сеть: одна VPC и по подсети в каждой зоне доступности.
# Три зоны нужны региональному мастеру Managed Kubernetes.
# ---------------------------------------------------------------------------

resource "yandex_vpc_network" "main" {
  name        = "diplom-network"
  description = "Основная сеть дипломного проекта"

  labels = var.common_labels
}

resource "yandex_vpc_subnet" "main" {
  count = length(var.zones)

  name           = "diplom-subnet-${var.zones[count.index]}"
  zone           = var.zones[count.index]
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.subnet_cidrs[count.index]]
  labels         = var.common_labels
}

# NAT-шлюз убран намеренно: маршрут 0.0.0.0/0 через него ломал обратный трафик
# от внешнего балансировщика. Узлы ходят в интернет через собственные
# публичные адреса.
