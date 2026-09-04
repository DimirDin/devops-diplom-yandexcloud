# Инфраструктура в Yandex Cloud

Два независимых конфигурационных каталога. Разделение обязательное, а не косметическое:
`terraform destroy` в `infra/` не должен уносить бакет, в котором лежит его собственный стейт.

```
bootstrap/   сервисные аккаунты + S3-бакет под стейт     локальный стейт, запускается один раз
infra/       VPC, Managed Kubernetes, Container Registry  стейт в бакете, пересоздаётся свободно
```

## 1. Bootstrap

Запускается от вашей учётной записи (`yc init` или `YC_TOKEN`), потому что создаёт сервисные аккаунты.

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars   # заполнить cloud_id, folder_id, имя бакета
terraform init
terraform apply
```

Забрать выводы:

```bash
terraform output -raw access_key
terraform output -raw secret_key
terraform output k8s_cluster_sa_id
terraform output k8s_node_sa_id
```

Ключи в стейте лежат открытым текстом — файл `terraform.tfstate` бутстрапа в git не попадает
(закрыт `.gitignore`) и не должен туда попасть.

## 2. Infra

```bash
cd terraform/infra
cp backend.hcl.example backend.hcl              # имя бакета из шага 1
cp terraform.tfvars.example terraform.tfvars    # id сервисных аккаунтов из шага 1

export AWS_ACCESS_KEY_ID=$(terraform -chdir=../bootstrap output -raw access_key)
export AWS_SECRET_ACCESS_KEY=$(terraform -chdir=../bootstrap output -raw secret_key)

terraform init -backend-config=backend.hcl
terraform apply
```

Проверка требования «destroy → apply без ручных действий»:

```bash
terraform destroy -auto-approve && terraform apply -auto-approve
```

## 3. Доступ к кластеру

```bash
$(terraform -chdir=terraform/infra output -raw kubeconfig_command)
kubectl get pods --all-namespaces
```

## Что сделано ради экономии

| Решение | Эффект | Цена решения |
|---|---|---|
| `core_fraction = 20` | ~в 3 раза дешевле vCPU | узлы медленные под нагрузкой |
| `preemptible = true` | примерно вдвое дешевле | узел может быть остановлен облаком, живёт ≤24 ч |
| 2 узла, диск 32 ГБ | минимум под мониторинг + приложение | запаса нет |
| Узлы без публичных IP, выход через NAT | не платим за белые адреса | доступ только через LoadBalancer/ingress |

Региональный мастер (три зоны) — требование задания, на нём не экономим.
