include variables.mk

.PHONY: build all run exec
.DEFAULT_GOAL := run

CONTAINER ?= sut

keys:
	openssl req -x509 -sha256 -nodes -newkey rsa:4096 -keyout config/key.pem -out config/certificate.pem -days 7200 -subj "/C=US/ST=/L=/O=/OU=Self Signed/CN=self.signed"

run:
	docker run -it --rm -v `pwd`/config/key.pem:/etc/ssl/key.pem -v `pwd`/config/certificate.pem:/etc/ssl/certificate.pem ${APPLICATION}:${BRANCH}

nuke:
	docker-compose -f docker-compose.test.yml down --rmi all --remove-orphans -v -t 1

clean:
	docker-compose -f docker-compose.test.yml down --remove-orphans -v

down:
	docker-compose -f docker-compose.test.yml down

up:
	docker-compose -f docker-compose.test.yml up

debug:
	docker start catchall-server-1
	docker commit $(shell docker ps -aqf "name=catchall-${CONTAINER}-1") debug

exec:
	docker run -it --rm --network=catchall_default --entrypoint=/bin/sh debug

sut: nuke
	docker-compose -f docker-compose.test.yml up --exit-code-from sut
