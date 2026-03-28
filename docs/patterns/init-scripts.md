# Init Script Patterns

## Purpose

Init scripts in `rootfs/etc/cont-init.d/` prepare runtime configuration before supervised services start.

## Naming and ordering

Use the format `NN-name-init`, where `NN` controls execution order.

Examples:

```text
01-timezone-init
02-ssl-init
08-dkim-init
10-postfix-init
20-dovecot-init
```

Choose numbers based on dependency order, not aesthetics.

## Standard init-script template

```sh
#!/command/with-contenv sh

# 1. Feature check
if [ -z "${FEATURE_ENABLED}" ]; then
    echo "[INFO  ] Feature disabled"
    exit 0
fi

# 2. Validate prerequisites
if [ ! -f "/path/to/requirement" ]; then
    echo "[WARN  ] Requirement missing; skipping"
    exit 0
fi

# 3. Execute setup
echo "[NOTICE] Configuring feature..."
mkdir -p /path/to/config
# ... do work ...
echo "[NOTICE] Feature configured"

# 4. Never crash the container for an optional feature path
exit 0
```

## Required conventions

- Use `#!/command/with-contenv sh`.
- Prefer POSIX `sh` over bash.
- Quote variables.
- Exit early when the feature is not configured.
- Log important steps.
- Do not background work in init scripts.
- Do not use `systemctl`.

## Config generation pattern

Generate config from env vars during init.

```sh
cat > /etc/service/config.conf <<CONFIGEOF
variable1 = ${ENV_VAR_1}
variable2 = ${ENV_VAR_2}
CONFIGEOF

chmod 644 /etc/service/config.conf
```

Use heredocs, `printf`, or `sed` depending on the file being generated. Keep generation logic readable.

## Secret handling pattern

For sensitive values, support both env vars and Docker Secret files.

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

## Common mistakes to avoid

- crashing the container because an optional feature is misconfigured
- using bash-only syntax in a POSIX `sh` script
- hardcoding runtime config that should come from env vars
- writing long opaque one-liners when a few readable steps are clearer
