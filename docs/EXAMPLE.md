# Complete Example: Catch-all with Email Processing

This document provides working examples of the catchall container configured for Gmail forwarding with optional email processing (logging, webhooks, external integrations).

## Architecture

```text
Internet SMTP (port 25)
         ↓
    Postfix SMTP Receiver
         ↓
   Virtual Aliases (route mail)
      ↙         │    ↖
   /dev/null  Gmail  Dovecot/Sieve
              (via   (processor)
               relay)  ├─ Pipe email to script
                       └─ Discard message
```

**Postfix handles routing:** Forward mail to Gmail while copying to Dovecot for processing.

**Dovecot handles processing:** Receive a copy, pipe to user script, discard (Postfix already forwarded).

---

## Configuration Variables

### Configuration Variables (from README.md)

| Variable | Purpose | Example |
| --- | --- | --- |
| `DOMAIN` | Primary domain to receive mail | `example.com` |
| `HOSTNAME` | Hostname for TLS certificates | `mail.example.com` |
| `ALIASES` | Additional domains to receive mail | `example.local example.net` |
| `CATCHALL` | Local account name (Dovecot user) | `catchall` |
| `FORWARD_TO` | Optional Gmail address to forward to | `your-email@gmail.com` |
| `DEVNULL` | Addresses to discard (spam) | `sales@example.com noreply@example.com` |
| `PASSWORD` | Dovecot user password | `your-secure-password` |
| `TIMEZONE` | Timezone for logs | `America/New_York` |

### Email Processor Variables

| Variable | Purpose | Example |
| --- | --- | --- |
| `PROCESSOR_SCRIPT` | Processor script content (inline) | `$(cat process-email.sh)` |
| `PROCESSOR_SCRIPT_FILE` | Path to processor script (Docker Secret) | `/run/secrets/email_processor` |
| `PROCESSOR_SCRIPT_URL` | URL to download processor script | `https://example.com/processor.sh` |

---

## Example Processor Scripts

### Example 1: Log to Syslog

```bash
#!/bin/sh
# Read email from stdin, log important headers
while read line; do
  if echo "$line" | grep -qE "^(From|Subject|To|Date):"; then
    logger -t email-processor "$line"
  fi
done
exit 0
```

### Example 2: Send Webhook Notification

```bash
#!/bin/sh
# Extract headers, send summary to webhook
WEBHOOK_URL="${PROCESSOR_WEBHOOK:-http://localhost:3000/email}"
EMAIL=$(cat)

FROM=$(echo "$EMAIL" | grep "^From:" | head -1 | sed 's/^From: *//')
SUBJECT=$(echo "$EMAIL" | grep "^Subject:" | head -1 | sed 's/^Subject: *//')
TO=$(echo "$EMAIL" | grep "^To:" | head -1 | sed 's/^To: *//')

curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"from\":\"$FROM\",\"subject\":\"$SUBJECT\",\"to\":\"$TO\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
  > /dev/null 2>&1

exit 0
```

### Example 3: Write JSON to File

```bash
#!/bin/sh
# Parse headers, append to JSONL file
EMAIL=$(cat)

FROM=$(echo "$EMAIL" | grep "^From:" | head -1 | sed 's/^From: *//')
SUBJECT=$(echo "$EMAIL" | grep "^Subject:" | head -1 | sed 's/^Subject: *//')

printf '{"from":"%s","subject":"%s","timestamp":"%s"}\n' \
  "$FROM" "$SUBJECT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> /shared/emails.jsonl

exit 0
```

---

## Docker Run Examples

`FORWARD_TO` requires a valid SPF and/or DKIM setup.

### Example 1: Basic Gmail Forwarding

```bash
docker run -d \
  --name catchall \
  -p 25:25 \
  -e DOMAIN="example.com" \
  -e HOSTNAME="mail.example.com" \
  -e FORWARD_TO="your-email@gmail.com" \
  jnovack/catchall
```

### Example 2: With DEVNULL (Spam Filtering)

```bash
docker run -d \
  --name catchall \
  -p 25:25 \
  -e DOMAIN="example.com" \
  -e HOSTNAME="mail.example.com" \
  -e FORWARD_TO="your-email@gmail.com" \
  -e DEVNULL="sales@example.com marketing@example.com noreply@example.com webmaster@example.com" \
  jnovack/catchall
```

### Example 3: With ALIASES (Multiple Domains)

```bash
docker run -d \
  --name catchall \
  -p 25:25 \
  -e DOMAIN="example.com" \
  -e HOSTNAME="mail.example.com" \
  -e FORWARD_TO="your-email@gmail.com" \
  -e ALIASES="example.local example.net staging.example.com" \
  -e DEVNULL="sales@example.com noreply@example.com" \
  jnovack/catchall
```

### Example 4: With Processor Script (Inline)

```bash
docker run -d \
  --name catchall \
  -p 25:25 \
  -e DOMAIN="example.com" \
  -e HOSTNAME="mail.example.com" \
  -e FORWARD_TO="your-email@gmail.com" \
  -e PROCESSOR_SCRIPT="$(cat process-email.sh)" \
  jnovack/catchall
```

### Example 5: With Processor Script (Download URL)

```bash
docker run -d \
  --name catchall \
  -p 25:25 \
  -e DOMAIN="example.com" \
  -e HOSTNAME="mail.example.com" \
  -e FORWARD_TO="your-email@gmail.com" \
  -e PROCESSOR_SCRIPT_URL="https://raw.githubusercontent.com/your-org/scripts/main/email-processor.sh" \
  jnovack/catchall
```

### Example 6: Complete Configuration

```bash
docker run -d \
  --name catchall \
  -p 25:25 \
  -p 993:993 \
  -e DOMAIN="example.com" \
  -e HOSTNAME="mail.example.com" \
  -e TIMEZONE="America/New_York" \
  -e FORWARD_TO="your-email@gmail.com" \
  -e PASSWORD="secure-password-here" \
  -e DEVNULL="sales@example.com marketing@example.com noreply@example.com" \
  -e ALIASES="example.local example.net" \
  -e PROCESSOR_SCRIPT="$(cat process-email.sh)" \
  -v mail-spool:/var/mail \
  -v certificates:/etc/letsencrypt/live/ \
  jnovack/catchall
```

---

## Docker Compose Example

**File: `docker-compose.yml`**

```yaml
version: '3.8'

services:
  catchall:
    image: jnovack/catchall
    container_name: mail-catchall

    ports:
      - "25:25"      # SMTP (inbound)
      - "993:993"    # IMAPS (optional; for direct access)
      - "995:995"    # POPS (optional; for direct access)

    environment:
      # Core configuration
      DOMAIN: example.com
      HOSTNAME: mail.example.com
      CATCHALL: catchall
      TIMEZONE: America/New_York

      # Mail forwarding (optional)
      FORWARD_TO: your-email@gmail.com

      # Spam filtering
      DEVNULL: |
        sales@example.com
        marketing@example.com
        noreply@example.com
        webmaster@example.com

      # Domain aliases
      ALIASES: "example.local example.net staging.example.com"

      # Email processor (one of three options below)
      # PROCESSOR_SCRIPT: "$(cat script.sh)"
      # PROCESSOR_SCRIPT_FILE: /run/secrets/email_processor
      # PROCESSOR_SCRIPT_URL: https://example.com/processor.sh

    secrets:
      - email_processor

    volumes:
      - mail-spool:/var/mail
      - certificates:/etc/letsencrypt/live/

    restart: unless-stopped

volumes:
  mail-spool:
    driver: local
  certificates:
    driver: local

secrets:
  email_processor:
    file: ./scripts/process-email.sh
```

Run with:

```bash
docker-compose up -d
docker-compose logs -f catchall
```

---

## Security: Internal Processor Address

**Problem:** If the processor address is a real domain, external users could send mail directly to it, potentially bypassing your filters.

**Solution:** Use an internal-only domain that is NOT in Postfix's accepted domains.

### Configuration

Update the Postfix init script to generate virtual aliases with internal routing:

**In `/etc/postfix/virtual`:**

```text
sales@example.com              /dev/null
marketing@example.com          /dev/null
noreply@example.com            /dev/null
@example.com                   your-email@gmail.com, processor@internal.local
```

**In `/etc/postfix/virtual_mailbox_domains`** (only list external domains):

```text
example.com
example.local
example.net
staging.example.com
```

### How It Works

- **External mail to `processor@internal.local`**: Rejected immediately (domain not in `virtual_mailbox_domains`). Attack surface eliminated.
- **Internal expansion from catch-all rule**: Postfix still routes to `processor@internal.local` because the virtual alias expansion is happening locally.
- **Result**: Processor address is "dark" to external attackers but fully functional for internal routing.

---

## Testing

### Test 1: Send Email (External)

```bash
# Using telnet/netcat
(
  echo "EHLO test.example.com"
  echo "MAIL FROM:<sender@external.com>"
  echo "RCPT TO:<user@example.com>"
  echo "DATA"
  echo "Subject: Test Email"
  echo "From: sender@external.com"
  echo "To: user@example.com"
  echo ""
  echo "This is a test email."
  echo "."
  echo "QUIT"
) | nc mail.example.com 25
```

### Test 2: Verify Gmail Receives It

Check your Gmail inbox for the forwarded message.

### Test 3: Verify Processor Runs

```bash
# Check container logs
docker logs catchall | grep -E "processor|NOTICE"

# If logging to syslog
docker exec catchall tail -50 /var/log/syslog | grep processor
```

### Test 4: Verify DEVNULL Filtering

```bash
# Send to a blackholed address
(
  echo "EHLO test.example.com"
  echo "MAIL FROM:<attacker@external.com>"
  echo "RCPT TO:<sales@example.com>"
  echo "DATA"
  echo "Subject: Spam"
  echo ""
  echo "This should be discarded"
  echo "."
  echo "QUIT"
) | nc mail.example.com 25

# Verify it was NOT forwarded to Gmail
docker logs catchall | grep -i sales
```

### Test 5: Verify Processor Address Is Not Externally Accessible

```bash
# Try to send directly to processor address (should be rejected)
(
  echo "EHLO test.example.com"
  echo "MAIL FROM:<attacker@external.com>"
  echo "RCPT TO:<processor@internal.local>"
  echo "DATA"
  echo "Subject: Attack"
  echo ""
  echo "Try to reach processor"
  echo "."
  echo "QUIT"
) | nc mail.example.com 25

# Should see: "550 5.1.1 <processor@internal.local>: Recipient address rejected"
docker logs catchall | grep -i "processor.*rejected"
```

---

## Troubleshooting

| Problem | Cause | Solution |
| --- | --- | --- |
| Mail not reaching Gmail | SPF/DMARC issues or relay misconfigured | See [FORWARDER.md](FORWARDER.md) for DNS setup |
| Processor script not running | Script not provided or path incorrect | Check env var is set; verify script is executable |
| DEVNULL not filtering | Addresses formatted incorrectly | Use format `address@domain.com` (not just `address`); rebuild virtual map |
| Processor getting external mail | Processor domain in ALIASES or virtual_mailbox_domains | Remove from both; use internal-only domain |

---

## References

- [FORWARDER.md](FORWARDER.md) — Gmail forwarding and SPF/DKIM setup
- [AGENTS.md](../AGENTS.md) — Architecture and coding patterns
- [Postfix Virtual Aliases](http://www.postfix.org/virtual.5.html)
- [Dovecot Sieve Filtering](https://wiki.dovecot.org/Sieve)
- [README.md](../README.md) — Environment variable reference
