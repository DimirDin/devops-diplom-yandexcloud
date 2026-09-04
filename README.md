# Дипломный проект: Yandex Cloud + Kubernetes + CI/CD

Инфраструктура, кластер, мониторинг и пайплайны для дипломной работы
[netology-code/devops-diplom-yandexcloud](https://github.com/netology-code/devops-diplom-yandexcloud).

## Структура

```
terraform/bootstrap/     сервисные аккаунты и бакет под стейт (разовый запуск)
terraform/infra/         VPC, Managed Kubernetes, Container Registry
kubernetes/              ingress-nginx, kube-prometheus-stack, манифесты приложения
app/                     тестовое приложение — переносится в отдельный репозиторий
.github/workflows/       terraform plan на PR, apply на main
```

## Принятые решения

| Пункт задания | Решение | Почему |
|---|---|---|
| Кластер | Managed Kubernetes, региональный мастер | Kubespray добавляет 3 VM и час отладки CNI, ничего не давая по существу |
| Реестр | Yandex Container Registry через Terraform | Не нужен внешний imagePullSecret: узлам хватает своего сервисного аккаунта |
| CI/CD | GitHub Actions | Jenkins/GitLab потребовали бы отдельной VM, выставленной наружу |
| Terraform-пайплайн | GitHub Actions вместо Atlantis | Тот же результат без ещё одной машины с вебхуками |
| Доступ по 80 порту | Один ingress-nginx + `nip.io` | Один внешний адрес на кластер вместо LoadBalancer на каждый сервис |

## Порядок выполнения

1. **[terraform/README.md](terraform/README.md)** — этапы 1 и 2: сервисный аккаунт,
   бакет со стейтом, сеть, кластер, реестр.
2. **[kubernetes/README.md](kubernetes/README.md)** — этап 4: ingress, мониторинг,
   деплой приложения.
3. **[app/](app/)** — этап 3: Dockerfile и статика. Каталог нужно вынести в
   **отдельный репозиторий** (задание требует именно этого) вместе с его
   `.github/workflows` — там лежит этап 5.

## Секреты GitHub Actions

В репозитории инфраструктуры (этот):

| Секрет | Откуда взять |
|---|---|
| `YC_SA_JSON_CREDENTIALS` | `yc iam key create --service-account-name terraform-sa -o key.json` |
| `YC_ACCESS_KEY` / `YC_SECRET_KEY` | `terraform -chdir=terraform/bootstrap output -raw access_key` / `secret_key` |
| `TF_STATE_BUCKET` | имя бакета из bootstrap |
| `YC_CLOUD_ID`, `YC_FOLDER_ID` | идентификаторы облака и каталога |
| `YC_K8S_CLUSTER_SA_ID`, `YC_K8S_NODE_SA_ID` | выводы bootstrap |

В репозитории приложения:

| Секрет | Откуда взять |
|---|---|
| `YC_SA_JSON_CREDENTIALS` | тот же ключ сервисного аккаунта |
| `YC_REGISTRY_ID` | `terraform -chdir=terraform/infra output -raw registry_id` |
| `YC_CLUSTER_ID` | `terraform -chdir=terraform/infra output -raw cluster_id` |

## Проверка результата

```bash
kubectl get pods --all-namespaces          # этап 2
curl -I http://app.$LB_IP.nip.io           # этап 4, приложение
curl -I http://grafana.$LB_IP.nip.io       # этап 4, Grafana
git tag v1.0.0 && git push origin v1.0.0   # этап 5, деплой по тегу
```
