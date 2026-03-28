# Troubleshooting

## Common issues

| Problem | Likely cause | Suggested check |
| -------- | -------- | -------- |
| Container will not start | Init script exited non-zero | Check `docker logs` and confirm optional paths end with `exit 0` |
| Mail is not forwarded | Postfix or Dovecot config issue | Inspect generated config and review service logs |
| Feature appears disabled | Env var missing or misspelled | Verify container environment and startup logs |
| Socket permission denied | Wrong user or permissions | Check ownership and permissions for sockets and runtime files |
| Config file not found | Init script did not render it | Verify the file path and startup order |

## Debug checklist

1. Check container logs:

   ```bash
   docker logs CONTAINER
   ```

2. Verify environment variables:

   ```bash
   docker inspect CONTAINER | grep Env
   ```

3. Inspect generated files:

   ```bash
   docker exec CONTAINER ls -la /etc/SERVICE/
   ```

4. Check service state when relevant:

   ```bash
   docker exec CONTAINER s6-svstat /run/service/SERVICE
   ```

5. Drop into a shell for direct inspection:

   ```bash
   docker run -it --entrypoint /bin/sh catchall:test
   ```

## Debugging guidance

- Prefer reading generated config before rewriting logic.
- Confirm startup ordering when a later service depends on earlier generated assets.
- Review whether an optional feature is correctly treating missing config as a skip path rather than a hard failure.
