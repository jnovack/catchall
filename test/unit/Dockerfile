FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
  bats \
  openssl \
  iproute2 \
  && rm -rf /var/lib/apt/lists/*

# Create the opendkim system user so chown calls in 08-dkim-init succeed.
RUN groupadd -r opendkim && useradd -r -g opendkim -s /usr/sbin/nologin opendkim

# Stub commands that the init scripts call via absolute path but are not
# installed in this minimal image. Each stub records its invocation to
# $STUB_LOG (an env var exported by the Bats setup() function).
RUN printf '#!/bin/sh\necho "postconf $*" >> "$STUB_LOG"\n' \
  > /usr/sbin/postconf && chmod +x /usr/sbin/postconf && \
  printf '#!/bin/sh\necho "postmap $*" >> "$STUB_LOG"\n' \
  > /usr/sbin/postmap && chmod +x /usr/sbin/postmap && \
  printf '#!/bin/sh\necho "postalias $*" >> "$STUB_LOG"\n' \
  > /usr/sbin/postalias && chmod +x /usr/sbin/postalias

# Stub curl (used for DKIM DNS validation — non-fatal if empty).
# Override via PATH so the iproute2 real `ip` is still reachable if needed.
RUN printf '#!/bin/sh\n# unit-test stub: suppress outbound DNS query\n' \
  > /usr/local/bin/curl && chmod +x /usr/local/bin/curl

# Pre-create directories that init scripts write into.
RUN mkdir -p /etc/opendkim/keys /etc/postfix /run/opendkim && \
  chown -R opendkim:opendkim /etc/opendkim /run/opendkim

COPY rootfs/etc/cont-init.d/ /scripts/
COPY test/unit/ /test/

WORKDIR /test
ENV TERM=xterm
CMD ["bats", "--formatter", "pretty", "/test"]
