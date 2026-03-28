# DKIM Signing (Optional)

## What is DKIM?

DKIM (DomainKeys Identified Mail) allows the catchall mail server to digitally sign outgoing
emails using a private key. Receiving mail servers can verify the signature using the public key
published in DNS, cryptographically proving the email came from your legitimate mail server and
hasn't been tampered with.

## When Do You Need DKIM?

DKIM is **optional** and becomes relevant when:

- **Email volume is high** (>5000 emails/day) — ISPs are more likely to check DKIM signatures
- **Sender reputation is critical** — You're concerned about spam filtering
- **DMARC compliance** — You have DMARC policies that require DKIM _or_ SPF alignment

For most small catchall deployments, **SPF is sufficient** and much simpler to configure.

## How DKIM Works

1. **Private key** (stored on mail server): Signs outgoing messages
2. **Public key** (in DNS): Allows receivers to verify the signature
3. **Mail server** (Postfix + OpenDKIM): Intercepts outgoing messages and signs them
4. **Receiving server** (Gmail, etc.): Checks the signature against the DNS public key

## Signing Scope

The catchall container signs **all outgoing mail** with your domain key — including mail that
originated from external senders and is being forwarded. The DKIM `d=` tag will be your domain
regardless of the message's `From:` address.

This adds a hop-level signature proving your server processed the message. It does not affect
DMARC alignment for the original sender (whose `From:` domain differs from yours), but it does
add authenticity context that some downstream systems consider.

## Setup

### Step 1 — Generate a keypair (once, outside the container)

```bash
openssl genrsa -out dkim.key 2048
openssl rsa -in dkim.key -pubout -out dkim.pub
```

### Step 2 — Get the public key value for DNS

```bash
grep -v '^-' dkim.pub | tr -d '\n'
```

### Step 3 — Publish public key in DNS

Add a TXT record to your domain:

```txt
default._domainkey.yourdomain.com  TXT  "v=DKIM1; k=rsa; p=<output from Step 2>"
```

Check propagation: `dig default._domainkey.yourdomain.com TXT`

### Step 4 — Pass the private key to the container

Via Docker Secret (recommended):

```bash
cat dkim.key | docker secret create dkim-private-key -
rm dkim.key
```

Then in your deployment under `server.environment`:

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

### Step 5 — Verify startup logs

Watch for:

```text
[NOTICE] DKIM DNS record verified: key matches
[NOTICE] DKIM configuration complete
```

If you see `[WARN] DKIM TXT record not found`, DNS has not propagated yet. Mail still flows
and will be signed once DNS is live — no restart needed.

## What the Container Does Automatically

When `DKIM_DOMAIN` is set, the container:

1. Reads the private key from `DKIM_PRIVATE_KEY_FILE` (or `DKIM_PRIVATE_KEY` env var)
2. Writes the key and signing tables to `/etc/opendkim/`
3. Configures Postfix to route all outbound mail through the OpenDKIM milter
4. Starts the OpenDKIM daemon
5. Validates the DNS record against the key (non-fatal warning if not found)

When `DKIM_DOMAIN` is **not** set, OpenDKIM idles and Postfix is not configured with a milter.
Mail flows normally without signing.

## Key Management

Keys are written fresh at each container start from the environment variable. There is no
persistent key volume — the private key lives only in your Docker Secret (or env var). This
is intentional: the container is ephemeral and re-reads config on every start.

## Comparison: SPF vs DKIM

| Aspect | SPF | DKIM |
| --- | --- | --- |
| **Complexity** | Very simple (1 DNS record) | More complex (OpenDKIM daemon) |
| **Setup time** | ~5 minutes | ~30 minutes |
| **DNS changes** | One TXT record | One TXT record + key management |
| **Key management** | None | Private key in Docker Secret |
| **Sufficient for Gmail** | Yes | No, but adds credibility |
| **Email throughput** | No impact | Minimal overhead |

## References

- [DKIM Specification (RFC 6376)](https://tools.ietf.org/html/rfc6376)
- [OpenDKIM Project](http://www.opendkim.org/)
- [DMARC Specification (RFC 7489)](https://tools.ietf.org/html/rfc7489)
