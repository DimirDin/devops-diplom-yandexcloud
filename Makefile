# Диплом: Yandex Cloud + Kubernetes.
#
# Цели разделены на бесплатные (проверки локально) и платные (создают ресурсы
# в облаке). Платные помечены явно — их запускаем, когда на счету есть деньги.

SHELL := /bin/bash
LB_IP ?= $(shell kubectl -n ingress-nginx get svc ingress-nginx-controller \
	-o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
REGISTRY_ID ?= $(shell terraform -chdir=terraform/infra output -raw registry_id 2>/dev/null)

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# --- Проверки: выполняются локально, ресурсы не создают ---------------------

.PHONY: check
check: tf-check helm-check ## Все локальные проверки

.PHONY: tf-check
tf-check: ## terraform fmt + validate в обоих каталогах
	terraform fmt -check -recursive terraform/
	terraform -chdir=terraform/bootstrap init -backend=false -input=false >/dev/null
	terraform -chdir=terraform/bootstrap validate
	terraform -chdir=terraform/infra init -backend=false -input=false >/dev/null
	terraform -chdir=terraform/infra validate

.PHONY: helm-check
helm-check: ## Отрендерить чарты с нашими values (ловит ошибки в values.yaml)
	helm template ingress-nginx ingress-nginx/ingress-nginx \
		--namespace ingress-nginx \
		--values kubernetes/ingress-nginx/values.yaml >/dev/null
	helm template monitoring prometheus-community/kube-prometheus-stack \
		--namespace monitoring \
		--values kubernetes/monitoring/values.yaml \
		--set 'grafana.ingress.hosts[0]=grafana.example.com' >/dev/null
	@echo "чарты рендерятся"

.PHONY: repos
repos: ## Добавить helm-репозитории (нужно один раз перед helm-check)
	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update

# --- Инфраструктура --------------------------------------------------------

.PHONY: bootstrap
bootstrap: ## SA + бакет под стейт (тарифицируется только объём хранения)
	terraform -chdir=terraform/bootstrap init
	terraform -chdir=terraform/bootstrap apply

.PHONY: network
network: ## Только сеть, без кластера
	terraform -chdir=terraform/infra apply \
		-target=yandex_vpc_network.main \
		-target=yandex_vpc_subnet.main \
		-target=yandex_vpc_route_table.nat \
		-target=yandex_vpc_gateway.nat

.PHONY: up
up: ## [$] Вся инфраструктура: сеть, кластер, реестр
	terraform -chdir=terraform/infra apply

.PHONY: down
down: ## Снести инфраструктуру (кроме bootstrap)
	terraform -chdir=terraform/infra destroy

.PHONY: stop
stop: ## Погасить кластер (мастер перестаёт тарифицироваться)
	yc managed-kubernetes cluster stop \
		--id $$(terraform -chdir=terraform/infra output -raw cluster_id)

.PHONY: start
start: ## Поднять погашенный кластер
	yc managed-kubernetes cluster start \
		--id $$(terraform -chdir=terraform/infra output -raw cluster_id)

.PHONY: kubeconfig
kubeconfig: ## Записать ~/.kube/config для кластера
	$$(terraform -chdir=terraform/infra output -raw kubeconfig_command)

# --- Установка в кластер ---------------------------------------------------

.PHONY: ingress
ingress: ## [$] ingress-nginx — заказывает сетевой балансировщик
	kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
		--namespace ingress-nginx --create-namespace \
		--values kubernetes/ingress-nginx/values.yaml

.PHONY: monitoring
monitoring: ## Поставить kube-prometheus-stack
	@test -n "$(LB_IP)" || { echo "LB_IP пуст: балансировщик ещё не получил адрес"; exit 1; }
	helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
		--namespace monitoring \
		--values kubernetes/monitoring/values.yaml \
		--set 'grafana.ingress.hosts[0]=grafana.$(LB_IP).nip.io'
	@echo "Grafana: http://grafana.$(LB_IP).nip.io"

.PHONY: grafana-secret
grafana-secret: ## Создать секрет с паролем Grafana
	kubectl -n monitoring create secret generic grafana-admin \
		--from-literal=admin-user=admin \
		--from-literal=admin-password="$$(openssl rand -base64 18)"
	@$(MAKE) --no-print-directory grafana-password

.PHONY: grafana-password
grafana-password: ## Показать пароль Grafana
	@kubectl -n monitoring get secret grafana-admin \
		-o jsonpath='{.data.admin-password}' | base64 -d; echo

.PHONY: app
app: ## Задеплоить тестовое приложение
	@test -n "$(LB_IP)" || { echo "LB_IP пуст"; exit 1; }
	@test -n "$(REGISTRY_ID)" || { echo "REGISTRY_ID пуст"; exit 1; }
	kubectl apply -f kubernetes/app/namespace.yaml
	sed 's|REGISTRY_ID|$(REGISTRY_ID)|' kubernetes/app/deployment.yaml | kubectl apply -f -
	kubectl apply -f kubernetes/app/service.yaml
	sed 's|APP_HOST|app.$(LB_IP).nip.io|' kubernetes/app/ingress.yaml | kubectl apply -f -
	kubectl -n app rollout status deployment/diplom-app
	@echo "Приложение: http://app.$(LB_IP).nip.io"

.PHONY: urls
urls: ## Показать адреса Grafana и приложения
	@echo "Grafana:     http://grafana.$(LB_IP).nip.io"
	@echo "Приложение:  http://app.$(LB_IP).nip.io"
