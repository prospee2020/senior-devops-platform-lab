# Senior DevOps Platform Lab — repeatable entry points.
# Run `make help` for the menu. Every target is safe to re-run (idempotent
# where the underlying tool allows it).

CLUSTER_NAME ?= platform-lab
IMAGE        ?= senior-devops-api
TAG          ?= dev
NAMESPACE    ?= dev

.PHONY: help tools-check cluster-up cluster-down app-build app-run app-test \
        app-load app-deploy validate port-forward load bf-bad-image \
        bf-broken-readiness bf-oom bf-clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

tools-check: ## Verify all required tools are installed and working
	./scripts/tools-check.sh

cluster-up: ## Create the local kind cluster (control-plane + worker)
	kind create cluster --config kind/cluster.yaml
	kubectl cluster-info --context kind-$(CLUSTER_NAME)

cluster-down: ## Destroy the kind cluster (all in-cluster state is lost)
	kind delete cluster --name $(CLUSTER_NAME)

app-build: ## Build the API container image
	docker build -t $(IMAGE):$(TAG) app/

app-run: ## Run the API locally in Docker on http://localhost:8000
	docker run --rm -p 8000:8000 --name $(IMAGE) $(IMAGE):$(TAG)

app-test: ## Run unit tests (requires: pip install -r app/requirements-dev.txt)
	cd app && python3 -m pytest tests/ -v

app-load: ## Load the locally-built image into the kind cluster nodes
	kind load docker-image $(IMAGE):$(TAG) --name $(CLUSTER_NAME)

app-deploy: ## Deploy the dev overlay (creates namespace if missing)
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -k k8s/overlays/dev
	kubectl -n $(NAMESPACE) rollout status deployment/senior-devops-api --timeout=90s

validate: ## Static validation: YAML, Python, shell, kustomize build
	./scripts/validate.sh

port-forward: ## Forward the dev Service to http://localhost:8080
	kubectl -n $(NAMESPACE) port-forward svc/senior-devops-api 8080:80

load: ## Send a small request load through the port-forward (run port-forward first)
	./scripts/load.sh

bf-bad-image: ## Break/Fix 1: deploy the bad-image scenario
	kubectl apply -f k8s/breakfix/01-bad-image.yaml

bf-broken-readiness: ## Break/Fix 2: deploy the broken-readiness scenario (needs app-load first)
	kubectl apply -f k8s/breakfix/02-broken-readiness.yaml

bf-oom: ## Break/Fix 3: deploy the OOM scenario
	kubectl apply -f k8s/breakfix/03-oom.yaml

bf-clean: ## Remove all break/fix scenarios
	kubectl delete namespace breakfix --ignore-not-found
