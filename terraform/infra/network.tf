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

# ---------------------------------------------------------------------------
# NAT-шлюз и таблица маршрутизации удаляются, но в два шага.
#
# Шаг 1 (этот коммит): подсети уже не ссылаются на таблицу, сами ресурсы ещё
# существуют. Шаг 2: ресурсы удаляются. Одним применением не выходит —
# Terraform пытается удалить таблицу раньше, чем отвяжет её от подсетей,
# и получает FailedPrecondition.
#
# Причина удаления: маршрут 0.0.0.0/0 через шлюз ломал обратный трафик от
# внешнего балансировщика. Узлы ходят в интернет через свои публичные адреса.
# ---------------------------------------------------------------------------

resource "yandex_vpc_gateway" "nat" {
  name = "diplom-nat-gateway"

  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "nat" {
  name       = "diplom-nat-route-table"
  network_id = yandex_vpc_network.main.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat.id
  }
}
