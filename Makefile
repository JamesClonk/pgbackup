.DEFAULT_GOAL := run
SHELL := /bin/bash
APP ?= $(shell basename $$(pwd) | tr '[:upper:]' '[:lower:]')
COMMIT_SHA = $(shell git rev-parse HEAD)

.PHONY: help
## help: prints this help message
help:
	@echo "Usage:"
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

.PHONY: run
## run: runs backup script
run:
	source .env; source .env_*; ./backup.sh

.PHONY: minio
## minio: runs minio backend on docker
minio: minio-stop minio-start
	docker logs minio -f

.PHONY: minio-cleanup
## minio-cleanup: cleans up minio backend
minio-cleanup: minio-stop
.PHONY: minio-stop
minio-stop:
	docker rm -f minio || true

.PHONY: minio-start
minio-start:
	docker run -d -p 9000:9000 --name minio \
		-e "MINIO_ACCESS_KEY=6d611e2d-330b-4e52-a27c-59064d6e8a62" \
		-e "MINIO_SECRET_KEY=eW9sbywgeW91IGhhdmUganVzdCBiZWVuIHRyb2xsZWQh" \
		minio/minio server /data

.PHONY: postgres
## postgres: runs postgres backend on docker
postgres: postgres-network postgres-stop postgres-start
	docker logs postgres -f

.PHONY: postgres-network
postgres-network:
	docker network create postgres-network --driver bridge || true

.PHONY: postgres-cleanup
## postgres-cleanup: cleans up postgres backend
postgres-cleanup: postgres-stop
.PHONY: postgres-stop
postgres-stop:
	docker rm -f postgres || true

.PHONY: postgres-start
postgres-start:
	docker run --name postgres \
		--network postgres-network \
		-e POSTGRES_USER='dev-user' \
		-e POSTGRES_PASSWORD='dev-secret' \
		-e POSTGRES_DB='my_postgres_db' \
		-p 5432:5432 \
		-d postgres:9-alpine

.PHONY: postgres-client
## postgres-client: connects to postgres backend with CLI
postgres-client:
	docker exec -it \
		-e PGPASSWORD='dev-secret' \
		postgres psql -U 'dev-user' -d 'my_postgres_db'

########################################################################################################################
####### docker/kubernetes related stuff ################################################################################
########################################################################################################################
.PHONY: image-login
## image-login: login to docker hub
image-login:
	@export PATH="$$HOME/bin:$$PATH"
	@echo $$DOCKER_PASS | docker login -u $$DOCKER_USER --password-stdin

.PHONY: image-build
## image-build: build docker image
image-build:
	@export PATH="$$HOME/bin:$$PATH"
	docker build -t jamesclonk/${APP}:${COMMIT_SHA} .

.PHONY: image-publish
## image-publish: build and publish docker image
image-publish:
	@export PATH="$$HOME/bin:$$PATH"
	docker push jamesclonk/${APP}:${COMMIT_SHA}
	docker tag jamesclonk/${APP}:${COMMIT_SHA} jamesclonk/${APP}:latest
	docker push jamesclonk/${APP}:latest

.PHONY: image-run
## image-run: run docker image
image-run:
	@export PATH="$$HOME/bin:$$PATH"
	docker run --rm --env-file .dockerenv jamesclonk/${APP}:${COMMIT_SHA}

.PHONY: cleanup
cleanup: docker-cleanup
.PHONY: docker-cleanup
## docker-cleanup: cleans up local docker images and volumes
docker-cleanup:
	docker system prune --volumes -a
