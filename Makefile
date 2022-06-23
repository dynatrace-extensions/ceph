SOURCES_DIR := src
ENTRYPOINT := extension.yaml
TOKEN_LOCATION := ./secrets/token
TENANT_LOCATION := ./secrets/tenant
DEV_HUB_TOKEN_LOCATION := ./secrets/dev_hub_token
DOCKER_PORT := ???
DOCKER_CONTAINER := ???/???:???
UPSTREAM_REPO := ssh://git@bitbucket.lab.dynatrace.org/dext2/mongodb-mongodb.git

.DEFAULT_GOAL := help
RETREIVE_API_TOKEN := $$(cat $(TOKEN_LOCATION))
RETREIVE_TENANT := $$(cat $(TENANT_LOCATION))
RETREIVE_DEV_HUB_TOKEN := $$(cat $(DEV_HUB_TOKEN_LOCATION))

SOURCES := $(shell find ./$(SOURCES_DIR)/ ! -type d)
_ENTRYPOINT := $(SOURCES_DIR)/$(ENTRYPOINT)
DOCKER_EXPOSED_PORT := $(DOCKER_PORT)
DOCKER_COMPANION_PORT := $(DOCKER_PORT) 

# Porcelain
# ###############
.PHONY: all run build lint test upload activate esure-dev-env env-dev-down env-dev-recreate env-dev-up env-container prerequisites-verify run-watch upstream

# this is a hack until --idtoken isn't required for local testing
RUN_CMD := dtsourceprometheus --url=file://CONSOLE --idtoken='.gitignore' --extConfig 'file://$(_ENTRYPOINT)' --userConfig 'file://local-activation.json'

run: ## run the extension locally
	$(RUN_CMD) | grep "MINT"

run-watch: ## run the extension in watch mode for rapid iteration
	ls $(SOURCES_DIR)/* | entr -c make run

run-verify: esure-dev-env ## run the extension locally - only show errors
	$(RUN_CMD) > /dev/null

debug: esure-dev-env ## run the extension locally with debug output
	$(RUN_CMD)

# this typo is deliberate, so that it doesn't show up when typing en[TAB]
esure-dev-env: env-dev-up

env-dev-up:  ## set up development environemnt, idempotent
	$(eval EXTENSION_FQN := $(shell yq < $(_ENTRYPOINT) '.name' | tr -d \"))
	$(eval DOCKER_NAME := echo $(shell companion-$(EXTENSION_FQN) | tr  : -))
	docker container inspect $(DOCKER_NAME) > /dev/null 2>&1 || (docker run --rm  --name $(DOCKER_NAME) -d -p $(DOCKER_EXPOSED_PORT):$(DOCKER_COMPANION_PORT) $(DOCKER_CONTAINER) && sleep 3)

env-dev-down: ## tear down development environment
	$(eval EXTENSION_FQN := $(shell yq < $(_ENTRYPOINT) '.name' | tr -d \"))
	$(eval DOCKER_NAME := $(shell companion-$(EXTENSION_FQN) | tr  : -))
	docker rm -f $(DOCKER_NAME)

env-dev-recreate: env-dev-down env-dev-up ## recreate developmenet environment
	$(eval EXTENSION_FQN := $(shell yq < $(_ENTRYPOINT) '.name' | tr -d \"))
	$(eval DOCKER_NAME := $(shell companion-$(EXTENSION_FQN) | tr  : -))
	docker logs -f $(DOCKER_NAME)

env-container:  ## containerize the build environment
	nix build docker.image -f default.nix
	$(eval EXTENSION_FQN := $(shell yq < $(_ENTRYPOINT) '.name' | tr -d \"))
	docker load < result
	docker tag extension-env:builded $(EXTENSION_FQN)-build-env:latest

all: upload activate ## make it work on the tenant

build: setup bundle.zip ## create artifact

lint: setup ## run static analysis
	yq < $(_ENTRYPOINT) > /dev/null
	@# TODO: lint against the actual schema

test: setup ## run all tests
	@echo "Not implemented"; false

upload: secrets/tenant secrets/token bundle.zip ## upload the extension
	curl -X POST "https://$(RETREIVE_TENANT)/api/v2/extensions" -H "accept: application/json; charset=utf-8" -H "Authorization: Api-Token $(RETREIVE_API_TOKEN)" -H "Content-Type: multipart/form-data" -F "file=@bundle.zip;type=application/x-zip-compressed" --silent | jq

activate: secrets/tenant secrets/token ## upload the configuration/activation
	$(eval EXTENSION_FQN := $(shell yq < $(_ENTRYPOINT) '.name' | tr -d \"))
	$(eval EXTENSION_VERSION := $(shell yq < $(_ENTRYPOINT) '.version' | tr -d \"))
	curl -X POST "https://$(RETREIVE_TENANT)/api/v2/extensions/$(EXTENSION_FQN)/environmentConfiguration" -H "accept: application/json; charset=utf-8" -H "Authorization: Api-Token $(RETREIVE_API_TOKEN)" -H "Content-Type: application/json" -d "{\"version\":\"$(EXTENSION_VERSION)\"}" --silent | jq
	sleep 10 # wait for the environement configuration to propagate
	curl -X POST "https://$(RETREIVE_TENANT)/api/v2/extensions/$(EXTENSION_FQN)/monitoringConfigurations" -H "accept: application/json; charset=utf-8" -H "Authorization: Api-Token $(RETREIVE_API_TOKEN)" -H "Content-Type: application/json" -d @remote-activation.json --silent | jq

prerequisites-verify:
	# TODO: should be datasrouce binary to be fully fool-proof
	@python -c "exit(not '$$(bash -c "printf '%q' "$$(which jq)"")'.startswith('/nix/store'))"
	@echo "Correct!"

upstream: ## create a PR to the internabl BB repo
	$(eval NAME := $(shell yq < $(_ENTRYPOINT) '.name' | tr -d \" | cut -d : -f 2))
	$(eval EXTENSION_VERSION := $(shell yq < $(_ENTRYPOINT) '.version' | tr -d \"))
	# TODO: generate tmp path - no need to clean! -> remove clean-upsteram and rm tmpath
	# TODO: move it up!
	$(eval TMP_UPSTEREAM_PATH := /tmp/$(NAME))
	# TODO: some sort of check for version number?

	git clone $(UPSTREAM_REPO) $(TMP_UPSTEREAM_PATH)
	rm -rf $(TMP_UPSTEREAM_PATH)/src/extension
	cp -R ./src $(TMP_UPSTEREAM_PATH)/src/extension

	sed -i 's/version=.*/version=$(EXTENSION_VERSION)/' $(TMP_UPSTEREAM_PATH)/version.properties
	./scripts/with-header-template ./src/extension.yaml > $(TMP_UPSTEREAM_PATH)/src/extension/extension.yaml

	cd $(TMP_UPSTEREAM_PATH) && git checkout -b $(EXTENSION_VERSION) && git add --all && git commit -m "update to $(EXTENSION_VERSION)" && git push -u origin $(EXTENSION_VERSION)
	rm -rf $(TMP_UPSTEREAM_PATH)
	echo "now, PR! link above!"

clean-upstream:
	#@ TODO: until this is somewhere else make sure to keep it in sync!
	$(eval NAME := $(shell yq < $(_ENTRYPOINT) '.name' | tr -d \" | cut -d : -f 2))
	$(eval TMP_UPSTEREAM_PATH := /tmp/$(NAME))
	rm -rf $(TMP_UPSTEREAM_PATH)

# Plumbing
# ###############
.PHONY: setup gitclean gitclean-with-libs raw-run

raw-run:
	$(RUN_CMD) | grep "MINT"

setup:

secrets:
	mkdir -p secrets

secrets/tenant:
	# Please provide a tenant url
	# Format: URL *without* protocol
	# Example: lwp00649.dev.dynatracelabs.com
	./scripts/acquire-secret $@

secrets/dev_hub_token:
	# TODO: fill this thing
	./scripts/acquire-secret $@

secrets/token:
	# Please provide a Dynatrace API token, obtained via:
	# (goto tentant UI) -> Settings -> Integration -> DynatraceAPI -> Generate token ->
	# -> (set name, doesn't matter) -> (set permissions, see below) -> Generate
	# under APIv2 following permissions are required:
	# - Write extensions
	# - Write extension environment configuration
	# - Write extension monitoring configuration
	# Format:  dt0c01.XXXXXXXXXXXXXXXXXXXXXXXX.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
	# Example: dt0c01.XYNU6UOAF2BJYI2LYPDWVHQI.K4COMU6UOQMOR7IRGHMTEDGTDOQI4HKR4QJ2O34ALTM2EPTYUQMQNMAXZQ32NTDI
	./scripts/acquire-secret $@

secrets/developer.pem:
	# TODO: actually have a proper process for this
	@echo "Not implemented"; false

secrets/developer.key:
	# copy the desired data from
	# https://secretserver.dynatrace.org/app/#/secret/22061/general
	# if you don't have access ask Olgierd
	#
	# for details:
	# see https://www.dynatrace.com/support/help/extend-dynatrace/extensions20/sign-extension/
	# or
	# possibly generate the keys in a known location and just symlink them here
	# in that case you should know what you're doing
	#
	# the pipeline will now fail - acquire the file and try again
	@false

extension.zip.sig: extension.zip secrets/developer.key secrets/developer.pem
	openssl cms -sign -signer secrets/developer.pem -inkey secrets/developer.key -binary -in extension.zip -outform PEM -out $@

extension.zip: $(SOURCES)
	(cd $(SOURCES_DIR) && zip -r $$OLDPWD/extension.zip .)

bundle.zip: extension.zip extension.zip.sig
	zip $@ extension.zip extension.zip.sig

# not really a PHONY, but we *really* don't want stale data here
.PHONY: signed-bundle.zip
signed-bundle.zip: ## downloads extension artifact in version passed in extension.yaml
	$(eval EXTENSION_FQN := $(shell yq < $(_ENTRYPOINT) '.name' | tr -d \" | sed 's/custom://' | sed 's/com.dynatrace.extension.//'))
	$(eval EXTENSION_VERSION := $(shell yq < $(_ENTRYPOINT) '.version' | tr -d \"))
	$(eval FILE_NAME := $(EXTENSION_FQN)-$(EXTENSION_VERSION).zip)
	wget "https://artifactory.lab.dynatrace.org/artifactory/extensions-release/com/dynatrace/extension/$(EXTENSION_FQN)/$(EXTENSION_VERSION)/$(FILE_NAME)"
	mv $(FILE_NAME) signed-bundle.zip

hub-dev: signed-bundle.zip ## sending extension to HUB DEV
	$(eval EXTENSION_FQN := $(shell yq < $(_ENTRYPOINT) '.name' | tr -d \" | sed 's/custom://' | sed 's/com.dynatrace.extension.//'))
	$(eval EXTENSION_VERSION := $(shell yq < $(_ENTRYPOINT) '.version' | tr -d \"))
	curl -X POST "https://hub-manager.spine-dev.internal.dynatracelabs.com/api/ci/extension/" -F "artifact=@signed-bundle.zip" -H "Authorization: Token $(RETREIVE_DEV_HUB_TOKEN)"

# TODO: fix this and push upstream
gitclean:
	@# will remove everything in .gitignore expect for blocks starting with dep* or lib* comment
	#diff --new-line-format="" --unchanged-line-format="" <(grep -v '^#' .gitignore | grep '\S' | sort) <(awk '/^# *(dep|lib)/,/^$/' testowy | head -n -1 | tail -n +2 | sort) | xargs rm -rf

gitclean-with-libs:
	diff --new-line-format="" --unchanged-line-format="" <(grep -v '^#' .gitignore | grep '\S' | sort) | xargs rm -rf


# Helpers
# ###############
rm-configuration: ## delete configuration
	$(eval EXTENSION_FQN := $(shell yq < $(_ENTRYPOINT) '.name' | tr -d \"))
	curl -X DELETE "https://$(RETREIVE_TENANT).dev.dynatracelabs.com/api/v2/extensions/$(EXTENSION_FQN)/monitoringConfigurations/$(ID)" -H "accept: application/json; charset=utf-8" -H "Authorization: Api-Token $(RETREIVE_API_TOKEN)" -H "Content-Type: application/json" --silent | jq

# Utilities
# ###############
.PHONY: help todo clean really_clean init
init: ## one time setup
	@# this is used to squash the "direnv is blocked" prompt which misguides the first time users, it's silenced to not show the error message if the clobber fails
	@-mv --no-clobber _.envrc .envrc 2>/dev/null
	direnv allow .

todo: ## list all TODOs in the project
	git grep -I --line-number TODO | grep -v 'list all TODOs in the project' | grep TODO

clean: gitclean ## remove artifacts
	rm -f extension.zip extension.zip.sig bundle.zip

really_clean: gitclean-with-libs ## remove EVERYTHING

help: ## print this message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
