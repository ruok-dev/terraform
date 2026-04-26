# Makefile — terraform-aws-infra
# Uso: make <alvo> ENV=<dev|staging|prod>
# Exemplo: make plan ENV=dev

SHELL := /bin/bash
.ONESHELL:
.DEFAULT_GOAL := help

# Cor
GREEN  := \033[0;32m
YELLOW := \033[1;33m
BLUE   := \033[0;34m
RESET  := \033[0m

ENV    ?= dev
ENVDIR := environments/$(ENV)

# Verifica que ENV é válido
guard-env:
	@if [ "$(ENV)" != "dev" ] && [ "$(ENV)" != "staging" ] && [ "$(ENV)" != "prod" ]; then \
		echo "❌ ENV inválido: '$(ENV)'. Use: make <alvo> ENV=dev|staging|prod"; \
		exit 1; \
	fi

## ── Ajuda ────────────────────────────────────────────────────────────────────
.PHONY: help
help: ## Mostra esta mensagem de ajuda
	@echo ""
	@echo "$(BLUE)terraform-aws-infra$(RESET) — Comandos disponíveis:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Exemplo:$(RESET) make plan ENV=staging"
	@echo ""

## ── Setup ────────────────────────────────────────────────────────────────────
.PHONY: install-tools
install-tools: ## Instala tfsec e checkov localmente
	@echo "Instalando ferramentas de segurança..."
	@if ! command -v tfsec &>/dev/null; then \
		curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash; \
		echo "$(GREEN)tfsec instalado$(RESET)"; \
	else \
		echo "tfsec já instalado: $$(tfsec --version)"; \
	fi
	@if ! command -v checkov &>/dev/null; then \
		pip install checkov --quiet; \
		echo "$(GREEN)checkov instalado$(RESET)"; \
	else \
		echo "checkov já instalado: $$(checkov --version)"; \
	fi

## ── Terraform ────────────────────────────────────────────────────────────────
.PHONY: init
init: guard-env ## Inicializa Terraform para o ambiente (ENV=dev)
	@echo "$(BLUE)→ terraform init [$(ENV)]$(RESET)"
	cd $(ENVDIR) && terraform init -input=false -reconfigure

.PHONY: fmt
fmt: ## Formata todos os arquivos .tf recursivamente
	@echo "$(BLUE)→ terraform fmt$(RESET)"
	terraform fmt -recursive .

.PHONY: fmt-check
fmt-check: ## Verifica formatação sem alterar arquivos
	terraform fmt -check -recursive .

.PHONY: validate
validate: guard-env ## Valida configuração do ambiente (ENV=dev)
	@echo "$(BLUE)→ terraform validate [$(ENV)]$(RESET)"
	cd $(ENVDIR) && terraform init -backend=false -input=false && terraform validate

.PHONY: plan
plan: guard-env ## Gera plano de execução (ENV=dev)
	@echo "$(BLUE)→ terraform plan [$(ENV)]$(RESET)"
	bash scripts/deploy.sh $(ENV) --plan-only 2>/dev/null || \
	(cd $(ENVDIR) && terraform init -input=false && terraform plan -var-file=terraform.tfvars)

.PHONY: apply
apply: guard-env ## Aplica infraestrutura (ENV=dev) — pede confirmação
	@echo "$(BLUE)→ terraform apply [$(ENV)]$(RESET)"
	bash scripts/deploy.sh $(ENV)

.PHONY: destroy
destroy: guard-env ## Destrói infraestrutura (prod bloqueado por padrão)
	bash scripts/destroy.sh $(ENV)

.PHONY: output
output: guard-env ## Exibe outputs do ambiente (ENV=dev)
	cd $(ENVDIR) && terraform output

.PHONY: state-list
state-list: guard-env ## Lista recursos no state (ENV=dev)
	cd $(ENVDIR) && terraform state list

## ── Segurança ─────────────────────────────────────────────────────────────────
.PHONY: scan
scan: ## Roda tfsec + checkov em todo o projeto
	@echo "$(BLUE)→ Security scan$(RESET)"
	bash scripts/validate.sh

.PHONY: tfsec
tfsec: ## Roda apenas o tfsec
	tfsec . --minimum-severity MEDIUM

.PHONY: checkov
checkov: ## Roda apenas o checkov
	checkov -d . --framework terraform --quiet --compact

.PHONY: check-creds
check-creds: ## Verifica se há credenciais hardcoded nos arquivos .tf
	@echo "$(BLUE)→ Verificando credenciais hardcoded...$(RESET)"
	@if grep -rn --include="*.tf" -E "(AKIA[0-9A-Z]{16}|password\s*=\s*\"[^${\"][^\"]{7,}\")" . \
		| grep -v "#" | grep -v "var\."; then \
		echo "$(YELLOW)⚠️  Credenciais encontradas acima!$(RESET)"; exit 1; \
	else \
		echo "$(GREEN)✅ Sem credenciais hardcoded.$(RESET)"; \
	fi

## ── CI/CD Local ──────────────────────────────────────────────────────────────
.PHONY: ci
ci: fmt-check check-creds scan validate ## Roda pipeline completo localmente (igual ao CI/CD)
	@echo "$(GREEN)✅ Pipeline local passou!$(RESET)"

## ── Utilitários ──────────────────────────────────────────────────────────────
.PHONY: clean
clean: ## Remove arquivos temporários (.terraform, planos, logs)
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.tfplan" -delete 2>/dev/null || true
	@find . -name "plan.out" -delete 2>/dev/null || true
	@find . -name "crash.log" -delete 2>/dev/null || true
	@echo "$(GREEN)Arquivos temporários removidos.$(RESET)"

.PHONY: docs
docs: ## Abre o README no terminal
	@cat README.md
