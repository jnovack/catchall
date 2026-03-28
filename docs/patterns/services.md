# s6 Service Patterns

## Purpose

Use s6-overlay for persistent background services. Do not use systemd inside the container.

## Standard layout

```text
rootfs/etc/s6-overlay/s6-rc.d/SERVICE_NAME/
├── type
├── run
└── dependencies.d/
    ├── parent-service1
    └── parent-service2
```

Register user-facing services under the user bundle as required by the existing repo layout.

## File details

### `type`

```text
longrun
```

### `run`

```sh
#!/command/execlineb -P
s6-setuidgid username
/usr/bin/my-service -f -c /etc/my-service/config.conf
```

### dependency entries

Dependency files in `dependencies.d/` should reference the required parent service names.

## Service best practices

- Run services in the foreground.
- Use execline in the run script when following the repo's existing s6 pattern.
- Drop to a non-root user where practical.
- Exit cleanly on termination.
- Log consistently using the repo's normal logging approach.

## When to use a service vs init script

Use an init script when the work is one-shot startup preparation.

Use an s6 service when the process must stay running for the life of the container.
