# Кластер: мониторинг и приложение

Порядок установки важен: сначала ingress-контроллер (он выдаёт внешний IP,
от которого зависят хосты Grafana и приложения), потом мониторинг, потом приложение.

## 0. Доступ к кластеру

```bash
$(terraform -chdir=../terraform/infra output -raw kubeconfig_command)
kubectl get pods --all-namespaces
```

## 1. Ingress-контроллер

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --values ingress-nginx/values.yaml
```

Дождаться внешнего адреса и запомнить его:

```bash
kubectl -n ingress-nginx get svc ingress-nginx-controller -w

export LB_IP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "$LB_IP"
```

`values.yaml` включает `serviceMonitor` в неймспейсе `monitoring` — поэтому этот
неймспейс создаётся заранее, до установки самого мониторинга.

## 2. Мониторинг

Пароль Grafana в git не хранится — кладём его в секрет отдельно:

```bash
kubectl -n monitoring create secret generic grafana-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$(openssl rand -base64 18)"

# Посмотреть пароль потом:
kubectl -n monitoring get secret grafana-admin \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

```bash
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values monitoring/values.yaml \
  --set grafana.ingress.hosts[0]="grafana.$LB_IP.nip.io"
```

Grafana: `http://grafana.<LB_IP>.nip.io` — 80 порт, как требует задание.
Дашборды состояния кластера приезжают вместе с чартом, плюс три добавленных
в `values.yaml` (Kubernetes Cluster, Node Exporter Full, NGINX Ingress).

## 3. Тестовое приложение

`REGISTRY_ID` берётся из `terraform -chdir=../terraform/infra output -raw registry_id`.

```bash
export REGISTRY_ID=$(terraform -chdir=../terraform/infra output -raw registry_id)

kubectl apply -f app/namespace.yaml
sed "s|REGISTRY_ID|$REGISTRY_ID|" app/deployment.yaml | kubectl apply -f -
kubectl apply -f app/service.yaml
sed "s|APP_HOST|app.$LB_IP.nip.io|" app/ingress.yaml | kubectl apply -f -

kubectl -n app rollout status deployment/diplom-app
```

Приложение: `http://app.<LB_IP>.nip.io`

## Почему nip.io

Своего домена в задании нет, а ingress-nginx разводит сервисы по именам хостов.
`nip.io` резолвит `что-угодно.1.2.3.4.nip.io` в `1.2.3.4` — получаем два имени
на одном внешнем адресе и один 80 порт. Если домен есть, подставьте его вместо
`nip.io` и заведите A-записи на `$LB_IP`.

## Про прерываемые узлы

Prometheus и Grafana держат PVC, а узлы прерываемые. При остановке узла диск
переедет вместе с подом, но пара минут недоступности будет. Перед защитой имеет
смысл выключить прерываемость:

```bash
terraform -chdir=../terraform/infra apply -var node_preemptible=false
```
