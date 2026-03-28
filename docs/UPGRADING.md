# Upgrading to Version 3

Version 3 is a **breaking change**. Read through all steps before deploying.

---

## What Changed

### Mail now goes to two places at once

In v3, setting `FORWARD_TO` sends mail to **both** externally **and** the local Dovecot
account. The local copy runs your Sieve scripts (webhooks, notifications, code
extraction, Mailpit relay). If you have no Sieve scripts configured, the local copy
accumulates in the local mailbox. If you want forward-only behavior with no local
accumulation, add this to your deployment:

```sh
GLOBAL_SIEVE="discard;"
```

### DKIM signing is now available (optional)

You can sign outgoing mail with a DKIM key. This is optional but improves deliverability.
See [DKIM.md](DKIM.md) for setup instructions.

---

## Upgrade Steps

### Step 1 — Update your SPF DNS record

Add or verify a TXT record on your domain:

```text
v=spf1 ip4:<YOUR_SERVER_IP> ~all
```

If you have multiple domains or aliases, add the record to each one.

Check it is live: `dig yourdomain.com TXT | grep spf`

### Step 2 — Add `FORWARD_TO` to your deployment

In your deployment file under `server.environment`:

```yaml
- "FORWARD_TO=your-gmail@gmail.com"
```

### Step 3 — Deploy the new image

```bash
docker stack deploy -c catchall.yml catchall
```

Or if using plain Docker Compose:

```bash
docker-compose up -d
```

### Step 4 — Send a test email

Send a message to any address on your domain and confirm it arrives in Gmail.
In Gmail, open the message, click the three-dot menu → **Show original**, and verify:

- `SPF: PASS`
- `Received:` chain includes your server's IP

---

## Optional: Add DKIM Signing

DKIM signing improves deliverability and proves your server sent the message.

### Step A — Generate a keypair (do this once, outside the container)

```bash
openssl genrsa -out dkim.key 2048
openssl rsa -in dkim.key -pubout -out dkim.pub
```

### Step B — Get the public key value for DNS

```bash
grep -v '^-' dkim.pub | tr -d '\n'
```

### Step C — Add DNS TXT record

Add to each of your domains:

```text
default._domainkey.yourdomain.com  TXT  "v=DKIM1; k=rsa; p=<output from Step B>"
```

Check propagation: `dig default._domainkey.yourdomain.com TXT`

### Step D — Store the private key as a Docker Secret

```bash
cat dkim.key | docker secret create dkim-private-key -
rm dkim.key
```

### Step E — Add to your deployment

Under `server.environment`:

```yaml
- "DKIM_DOMAIN=yourdomain.com"
- "DKIM_SELECTOR=default"
- "DKIM_PRIVATE_KEY_FILE=/run/secrets/dkim-private-key"
```

Under `server.secrets`:

```yaml
- dkim-private-key
```

Under top-level `secrets`:

```yaml
dkim-private-key:
  external: true
```

Raise the server memory limit:

```yaml
memory: 64M
```

### Step F — Deploy and verify

```bash
docker stack deploy -c config/deployment.yml catchall
```

Watch the startup logs for:

```text
[NOTICE] DKIM DNS record verified: key matches
[NOTICE] DKIM configuration complete
```

If you see `[WARN] DKIM TXT record not found`, DNS has not propagated yet. Mail still
flows and will be signed once DNS is live — no restart needed.

Send a test email to Gmail and check the original headers for `DKIM-Signature:`.

---

## Optional: Add Mailpit Web UI

Mailpit gives you a web inbox to browse received mail without going to Gmail.
Mail is delivered to Mailpit via a Sieve redirect from the local copy.

### Step A — Deploy Mailpit alongside the catchall server

The `config/deployment.yml` already includes the Mailpit service definition. Deploy
as-is; Mailpit starts with the stack.

Mailpit's web UI is available on port `8025`. Put it behind a reverse proxy with
client-certificate authentication before exposing it.

### Step B — Configure Sieve to redirect a copy to Mailpit

Add to your deployment under `server.environment`:

```yaml
- |
  GLOBAL_SIEVE=require ["copy", "redirect"];
  redirect :copy "catchall@mailpit";
```

This sends every delivered message to Mailpit while also keeping the local copy for
any further Sieve processing.

---

## Rollback

To return to v2 behavior (local-only, no forwarding):

1. Remove `FORWARD_TO` from your deployment
2. Redeploy

Mail will be stored locally and accessible via IMAP/POP3. Sieve scripts continue to
run on all delivered mail.
