# ---------------------------------------------------------------------------
# Сеть: одна VPC и по подсети в каждой зоне доступности.
# Три зоны нужны региональному мастеру Managed Kubernetes.
# ---------------------------------------------------------------------------

resource "yandex_vpc_network" "main" {
  name        = "diplom-network"
  description = "Основная сеть дипломного проекта"
}

resource "yandex_vpc_subnet" "main" {
  count = length(var.zones)

  name           = "diplom-subnet-${var.zones[count.index]}"
  zone           = var.zones[count.index]
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.subnet_cidrs[count.index]]
  route_table_id = yandex_vpc_route_table.nat.id
}

# ---------------------------------------------------------------------------
# NAT-шлюз: узлы кластера сидят без публичных адресов, но им нужен исход
# в интернет — тянуть образы и обновления.
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
