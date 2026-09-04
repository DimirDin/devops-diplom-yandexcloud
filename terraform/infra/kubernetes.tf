# ---------------------------------------------------------------------------
# Managed Kubernetes: региональный мастер, разложенный по трём подсетям.
#
# Про стоимость: региональный мастер отказоустойчив, но тарифицируется дороже
# зонального. Задание требует именно региональный, экономим на узлах.
# ---------------------------------------------------------------------------

resource "yandex_kubernetes_cluster" "main" {
  name        = "diplom-k8s"
  description = "Кластер дипломного проекта"

  network_id = yandex_vpc_network.main.id

  master {
    version = var.k8s_version

    dynamic "master_location" {
      for_each = var.zones

      content {
        zone      = master_location.value
        subnet_id = yandex_vpc_subnet.main[master_location.key].id
      }
    }

    public_ip = true

    maintenance_policy {
      auto_upgrade = false
    }
  }

  cluster_ipv4_range = var.cluster_ipv4_range
  service_ipv4_range = var.service_ipv4_range

  service_account_id      = var.k8s_cluster_sa_id
  node_service_account_id = var.k8s_node_sa_id

  release_channel = "STABLE"
}

# ---------------------------------------------------------------------------
# Группа узлов.
#
# Прерываемые узлы с урезанной долей vCPU — требование задания по экономии.
# Важно понимать цену решения: такой узел может быть остановлен облаком в
# любой момент и живёт не дольше 24 часов, поэтому поды переезжают. Для
# демонстрации это нормально, для продакшена — нет.
# ---------------------------------------------------------------------------

resource "yandex_kubernetes_node_group" "main" {
  cluster_id  = yandex_kubernetes_cluster.main.id
  name        = "diplom-node-group"
  description = "Рабочие узлы кластера"
  version     = var.k8s_version

  instance_template {
    platform_id = "standard-v3"

    network_interface {
      nat        = false
      subnet_ids = [yandex_vpc_subnet.main[0].id]
    }

    resources {
      cores         = var.node_cores
      memory        = var.node_memory
      core_fraction = var.node_core_fraction
    }

    boot_disk {
      type = "network-hdd"
      size = var.node_disk_size
    }

    scheduling_policy {
      preemptible = var.node_preemptible
    }

    container_runtime {
      type = "containerd"
    }
  }

  scale_policy {
    fixed_scale {
      size = var.node_count
    }
  }

  allocation_policy {
    location {
      zone = var.zones[0]
    }
  }

  maintenance_policy {
    auto_upgrade = false
    auto_repair  = true
  }
}
