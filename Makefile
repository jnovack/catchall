include variables.mk

.PHONY: build all run exec nuke sut sut-basic test-dkim test-global-sieve _sut-run-basic _sut-run-global-sieve _sut-run-dkim
.DEFAULT_GOAL := run

CONTAINER ?= sut

keys:
	openssl req -x509 -sha256 -nodes -newkey rsa:4096 -keyout config/key.pem -out config/certificate.pem -days 7200 -subj "/C=US/ST=/L=/O=/OU=Self Signed/CN=self.signed"

run:
	docker run -it --rm -v `pwd`/config/key.pem:/etc/ssl/key.pem -v `pwd`/config/certificate.pem:/etc/ssl/certificate.pem ${APPLICATION}:${BRANCH}

build:
	docker buildx build --platform linux/amd64,linux/arm64 . -t jnovack/catchall:latest

nuke:
	docker-compose -f test/basic/docker-compose.test.yml down --rmi all --remove-orphans -v -t 1
	docker-compose -f test/dkim/docker-compose.test.yml down --rmi all --remove-orphans -v -t 1
	docker-compose -f test/global-sieve/docker-compose.test.yml down --rmi all --remove-orphans -v -t 1

debug:
	docker start catchall-server-1
	docker commit $(shell docker ps -aqf "name=catchall-${CONTAINER}-1") debug

exec:
	docker run -it --rm --network=catchall_default --entrypoint=/bin/sh debug

_sut-run-basic:
	docker-compose -f test/basic/docker-compose.test.yml up --exit-code-from sut

_sut-run-global-sieve:
	docker-compose -f test/global-sieve/docker-compose.test.yml up --exit-code-from sut
	docker-compose -f test/global-sieve/docker-compose.test.yml logs server | grep -q "Installing global sieve from GLOBAL_SIEVE env"
	docker-compose -f test/global-sieve/docker-compose.test.yml logs server | grep -q "Effective sieve_before:"
	! docker-compose -f test/global-sieve/docker-compose.test.yml logs server | grep -q "plugin/sieve_before is empty"
	! docker-compose -f test/global-sieve/docker-compose.test.yml logs server | grep -q "Failed to compile global sieve"

_sut-run-dkim:
	docker-compose -f test/dkim/docker-compose.test.yml up --exit-code-from sut

sut: nuke _sut-run-basic _sut-run-global-sieve _sut-run-dkim

sut-basic: nuke _sut-run-basic

test-dkim: nuke _sut-run-dkim

test-global-sieve: nuke
	$(MAKE) _sut-run-global-sieve
