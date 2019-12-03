FROM alpine:latest

ARG BUILD_RFC3339="1970-01-01T00:00:00Z"
ARG COMMIT="local"
ARG VERSION="dirty"

EXPOSE 25
EXPOSE 995

ENTRYPOINT [ "/init" ]

ARG S6_OVERLAY_VERSION=v1.22.1.0

LABEL org.opencontainers.image.ref.name="jnovack/mailserver" \
      org.opencontainers.image.created=$BUILD_RFC3339 \
      org.opencontainers.image.authors="Justin J. Novack <jnovack@gmail.com>" \
      org.opencontainers.image.documentation="https://github.com/jnovack/docker-mailserver/README.md" \
      org.opencontainers.image.description="Simple mailserver docker container with postfix and dovecot." \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/jnovack/docker-mailserver" \
      org.opencontainers.image.revision=$COMMIT \
      org.opencontainers.image.version=$VERSION \
      org.opencontainers.image.url="https://hub.docker.com/r/jnovack/mailserver/"

RUN apk add --no-cache s6 postfix rsyslog tzdata pwgen dovecot dovecot-pop3d curl && \
    curl -sSL https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-amd64.tar.gz | tar xfz - -C / && \
    mkdir -p /var/mail && \
    chown mail.mail /var/mail && \
    addgroup -g 65530 catchall && \
    adduser -u 65530 -G catchall -D catchall

COPY rootfs /

ENV S6_LOGGING=0
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
ENV TIMEZONE="Etc/UTC"
CMD ["/usr/bin/tail", "-f", "/var/log/messages"]
