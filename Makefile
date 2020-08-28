include variables.mk

.PHONY: build all run exec
.DEFAULT_GOAL := run

keys:
	openssl req -x509 -sha256 -nodes -newkey rsa:4096 -keyout config/key.pem -out config/certificate.pem -days 7200 -subj "/C=US/ST=/L=/O=/OU=Self Signed/CN=self.signed"

run:
	docker run -it --rm -v `pwd`/config/key.pem:/etc/ssl/key.pem -v `pwd`/config/certificate.pem:/etc/ssl/certificate.pem ${APPLICATION}:${BRANCH}

exec:
	docker run -it --rm --entrypoint=/bin/sh ${APPLICATION}:${BRANCH}
