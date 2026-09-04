# Дипломный проект: Yandex Cloud + Kubernetes + CI/CD

Инфраструктура, кластер, мониторинг и пайплайны для дипломной работы
[netology-code/devops-diplom-yandexcloud](https://github.com/netology-code/devops-diplom-yandexcloud).

## Структура

```
terraform/bootstrap/     сервисные аккаунты и бакет под стейт (разовый запуск)
terraform/infra/         VPC, Managed Kubernetes, Container Registry
kubernetes/              ingress-nginx, kube-prometheus-stack, манифесты приложения
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

## Оптимизация расходов

Задание требует минимизировать стоимость инфраструктуры. Принятые решения и их цена:

| Решение | Что даёт | Чем платим |
|---|---|---|
| `core_fraction = 20` | гарантирована пятая часть vCPU вместо целого | узлы медленные под нагрузкой |
| `preemptible = true` | прерываемые узлы существенно дешевле обычных | узел может быть остановлен облаком, живёт не дольше 24 часов |
| 2 узла, диски 32 ГБ | минимум под мониторинг и приложение | запаса под рост нет |
| Узлы без публичных IP, выход через NAT | не платим за белые адреса на каждом узле | доступ снаружи только через ingress |
| Один ingress-nginx на кластер | один сетевой балансировщик вместо `LoadBalancer` на каждый сервис | единая точка отказа |
| Retention Prometheus 3 дня | PVC на 8 ГБ вместо десятков | истории метрик почти нет |

Региональный мастер (три зоны доступности) — прямое требование задания,
на нём не экономим, хотя зональный дешевле.

Прерываемость вынесена в переменную: перед демонстрацией имеет смысл
её отключить, чтобы узел не погас в неподходящий момент.

```bash
terraform -chdir=terraform/infra apply -var node_preemptible=false
```

## Локальные проверки

Всё это работает без облака и без секретов — конфигурация проверяется до создания ресурсов:

```bash
make check
```

`terraform fmt` и `validate` в обоих каталогах плюс рендер обоих helm-чартов
с нашими values. То же самое выполняет [lint.yml](.github/workflows/lint.yml)
на каждый push и pull request, добавляя проверку манифестов по схемам Kubernetes.

## Порядок выполнения

1. **[terraform/README.md](terraform/README.md)** — этапы 1 и 2: сервисный аккаунт,
   бакет со стейтом, сеть, кластер, реестр.
2. **[kubernetes/README.md](kubernetes/README.md)** — этап 4: ingress, мониторинг,
   деплой приложения.
3. **[DimirDin/diplom-app](https://github.com/DimirDin/diplom-app)** — этапы 3 и 5:
   Dockerfile, статика и пайплайны сборки и деплоя. Вынесено в отдельный
   репозиторий, как требует задание.

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
