FROM alpine:latest

ARG APPLICATION="myapp"
ARG BUILD_RFC3339="1970-01-01T00:00:00Z"
ARG REVISION="local"
ARG DESCRIPTION="no description"
ARG PACKAGE="user/repo"
ARG VERSION="dirty"

EXPOSE 25
EXPOSE 993
EXPOSE 995

ENTRYPOINT [ "/init" ]

ARG S6_OVERLAY_VERSION=3.2.0.2

LABEL org.opencontainers.image.ref.name="${PACKAGE}" \
    org.opencontainers.image.created=$BUILD_RFC3339 \
    org.opencontainers.image.authors="Justin J. Novack <jnovack@gmail.com>" \
    org.opencontainers.image.documentation="https://github.com/${PACKAGE}/README.md" \
    org.opencontainers.image.description="${DESCRIPTION}" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.source="https://github.com/${PACKAGE}" \
    org.opencontainers.image.revision=$REVISION \
    org.opencontainers.image.version=$VERSION \
    org.opencontainers.image.url="https://hub.docker.com/r/${PACKAGE}/"

RUN apk add --no-cache s6 postfix rsyslog tzdata pwgen dovecot dovecot-pop3d curl && \
    mkdir -p /var/mail && \
    chown mail:mail /var/mail && \
    addgroup -g 65530 catchall && \
    adduser -u 65530 -G catchall -D catchall

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz

COPY rootfs /

ENV S6_LOGGING=0
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
ENV TIMEZONE="Etc/UTC"
ENV \
    APPLICATION="${APPLICATION}" \
    BUILD_RFC3339="${BUILD_RFC3339}" \
    REVISION="${REVISION}" \
    DESCRIPTION="${DESCRIPTION}" \
    PACKAGE="${PACKAGE}" \
    VERSION="${VERSION}"

CMD ["/usr/bin/tail", "-f", "/var/log/messages"]
