# Architecture

## Project philosophy

Catchall is designed for self-hosted deployment by users with basic Docker and Linux knowledge. Features should default to simple behavior, minimize operator burden, and avoid surprising breakage.

### Design principles

1. Environment-variable driven configuration — settings come from env vars or Docker Secrets, not user-edited config files inside the container.
2. Minimal operator burden — setup should mostly happen automatically at startup.
3. Graceful degradation — optional features should fail safely without breaking core mail delivery.
4. Backward compatibility — new features should not affect existing deployments and should default to off unless clearly safe.
5. Ephemeral container model — except for the mail spool, the container should be treated as disposable.
6. Logging clarity — operators should be able to understand what happened from logs alone.

## Base stack

- Base image: Ubuntu 24.04 LTS
- Service supervisor: s6-overlay
- Mail stack:
  - Postfix for SMTP (port 25, with opportunistic STARTTLS)
  - Dovecot for IMAP, POP3, and LMTP (ports 993/995, TLS required)
  - Sieve for filtering and delivery rules
  - OpenDKIM for DKIM signing (optional, milter on `inet:8891`)

## Initialization order

Initialization scripts live in `rootfs/etc/cont-init.d/` and run in numeric order.

```text
01-timezone-init
02-ssl-init
08-dkim-init
10-postfix-init
20-dovecot-init
```

Use `NN-name-init` naming, where lower numbers run earlier. Pick numbers based on real dependencies.

### Ordering guidance

- Timezone and certificate setup should happen before services that consume them.
- DKIM initialization must happen before Postfix if Postfix depends on generated DKIM assets.
- Dovecot setup should happen after mail transport configuration it depends on.

## Configuration model

### Environment variables

All user-configurable features should be controlled through environment variables.

Naming pattern:

- `FEATURE_ENABLED` or `FEATURE_NAME` for the main switch/value
- `FEATURE_OPTION` for optional sub-settings
- Uppercase with underscores, for example:
  - `DKIM_DOMAIN`
  - `FORWARD_TO_GMAIL`
  - `SIEVE_SCRIPT_PATH`

### Docker Secrets support

Sensitive settings should support both direct env vars and file-based secret injection.

Typical pattern:

```sh
secret=""

if [ -n "${SECRET_VALUE}" ]; then
    secret="${SECRET_VALUE}"
fi

if [ -n "${SECRET_FILE}" ] && [ -f "${SECRET_FILE}" ]; then
    secret=$(cat "${SECRET_FILE}")
fi

if [ -z "${secret}" ]; then
    echo "[WARN  ] No secret provided; skipping"
    exit 0
fi
```

### Configuration files

Store templates and config fragments under `rootfs/etc/SERVICE_NAME/` and generate runtime config during container startup.

Example layout:

```text
rootfs/etc/postfix/
rootfs/etc/dovecot/
rootfs/etc/dovecot/sieve/
```

Avoid these patterns unless there is a strong project-specific reason:

- persistent config volumes for generated runtime config
- user-editable config files inside the running container
- hardcoded operator settings inside init scripts

## Logging conventions

Use clear prefixes so operators can follow startup and feature behavior.

```text
[INFO  ] Minor informational message
[NOTICE] Important lifecycle or configuration step
[WARN  ] Non-fatal issue or skipped optional feature
[ERROR ] Critical problem
```

Use `echo` for one-shot init script logging and system logging tools such as `logger` for long-running services when appropriate.
