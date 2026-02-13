.PHONY: init plan apply destroy

ENV ?= dev

TFVARS := environments/$(ENV).tfvars

init:
	cd terraform && terraform init -no-color

plan: init
	cd terraform && terraform workspace select -or-create $(ENV) && \
		terraform plan -var-file="$(TFVARS)" -no-color

apply: init
	cd terraform && terraform workspace select -or-create $(ENV) && \
		terraform plan -var-file="$(TFVARS)" -no-color -out="tfplan" && \
		terraform apply -no-color -auto-approve tfplan

destroy: init
	cd terraform && terraform workspace select -or-create $(ENV) && \
		terraform destroy -var-file="$(TFVARS)" -no-color
