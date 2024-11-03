NAME := sftp
TAG  := debian-12.6-03
TAG2 := debian
IMAGE_NAME := colmenaeu/$(NAME)

.PHONY: build build-local bash run run-ssl help push clean

build: ## Build for publishing
	docker build --pull -t $(IMAGE_NAME):$(TAG2) .

build-local: ## Builds with local users UID and GID
	docker build --build-arg FTP_UID=$(shell id -u) --build-arg FTP_GID=$(shell id -g) -t $(IMAGE_NAME):$(TAG) .

bash:
	docker run --rm -it $(IMAGE_NAME):$(TAG) bash

env:
	@echo "FTP_USER=ftp" >> env
	@echo "FTP_PASSWORD=ftp" >> env

vsftpd.pem:
	openssl req -new -newkey rsa:2048 -days 365 -nodes -sha256 -x509 -keyout vsftpd.pem -out vsftpd.pem -subj '/CN=self_signed'

run: env
	$(eval ID := $(shell docker run -d --env-file env -v $(shell pwd)/srv:/srv ${IMAGE_NAME}:${TAG}))
	$(eval IP := $(shell docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${ID}))
	@echo "Running ${ID} @ ftp://${IP}"
	@docker attach ${ID}
	@docker kill ${ID}

run-ssl: env vsftpd.pem
	$(eval ID := $(shell docker run -d --env-file env -v $(shell pwd)/srv:/srv -v $(PWD)/vsftpd.pem:/etc/ssl/certs/vsftpd.crt -v $(PWD)/vsftpd.pem:/etc/ssl/private/vsftpd.key ${IMAGE_NAME}:${TAG} vsftpd /etc/vsftpd_ssl.conf))
	$(eval IP := $(shell docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${ID}))
	@echo "Running ${ID} @ ftp://${IP}"
	@docker attach ${ID}
	@docker kill ${ID}

push: ## Pushes the docker image to hub.docker.com
	docker push $(IMAGE_NAME) --all-tags

clean: ## Remove built images
	docker rmi $(IMAGE_NAME):$(TAG)

#
# Help magic
#
help: ## show help message
	@awk \
	'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} \
	/^[$$()% 0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } \
	/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' \
	$(MAKEFILE_LIST)

