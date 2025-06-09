# ==== 変数定義 ====
PROJECT_ID           := tomoki-sandbox
IMAGE_NAME           := simple-api
IMAGE_TAG            := v1
ZONE                 := asia-northeast1-a
CLUSTER_NAME         := simple-cluster
NAMESPACE            := default
DEPLOYMENT_YAML      := deployment.yaml

# Artifact Registry 用設定
AR_LOCATION          := asia-northeast1
AR_REPOSITORY        := my-repo
AR_HOST              := $(AR_LOCATION)-docker.pkg.dev
AR_REPO_PATH         := $(AR_HOST)/$(PROJECT_ID)/$(AR_REPOSITORY)
IMAGE_URI            := $(AR_REPO_PATH)/$(IMAGE_NAME):$(IMAGE_TAG)

# ==== デフォルトターゲット ====
.PHONY: all
all: build push deploy

# ==== コンテナビルド & プッシュ ====
.PHONY: build
build:
	docker buildx build --platform linux/amd64 -t $(IMAGE_URI) . --push

.PHONY: push
push: build
	@echo "Image already pushed via buildx"

# ==== GKE クラスター操作 ====
.PHONY: cluster-create
cluster-create:
	gcloud container clusters create $(CLUSTER_NAME) \
		--project $(PROJECT_ID) \
		--zone $(ZONE) \
		--num-nodes 1 \
		--machine-type e2-medium

.PHONY: cluster-delete
cluster-delete:
	gcloud container clusters delete $(CLUSTER_NAME) \
		--project $(PROJECT_ID) \
		--zone $(ZONE) --quiet

# ==== デプロイ & 管理 ====
.PHONY: deploy
deploy: push
	kubectl apply -f $(DEPLOYMENT_YAML)

.PHONY: rollout-status
rollout-status:
	kubectl rollout status deployment/$(IMAGE_NAME) \
		-n $(NAMESPACE)

.PHONY: get-ip
get-ip:
	@echo "External IP/Hostname:"
	@kubectl get svc $(IMAGE_NAME)-lb \
		-n $(NAMESPACE) \
		-o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\\n"}{.status.loadBalancer.ingress[0].hostname}{"\\n"}'
	@echo ""
	@echo "Full service details:"
	@kubectl get svc $(IMAGE_NAME)-lb -o wide

# マニフェストを適用
.PHONY: apply
apply:
	kubectl apply -f $(DEPLOYMENT_YAML)

# Podの状態を確認
.PHONY: get-pods
get-pods:
	@kubectl get pods -o wide

# ==== クリーンアップ ====
.PHONY: clean
clean:
	docker rmi $(IMAGE_URI) || true

.PHONY: uninstall
uninstall:
	kubectl delete -f $(DEPLOYMENT_YAML) --ignore-not-found
