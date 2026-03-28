# Email Forwarding to Gmail

Since Gmail discontinued POP3 support, the **catchall** container can forward all received emails directly to a Gmail account using standard SMTP.

## Overview

When `FORWARD_TO` is set, the catchall server delivers each received message to **two destinations simultaneously**:

1. **External address (Gmail)** — via Postfix relay, no authentication required. This is the primary inbox.
2. **Local catchall account (Dovecot)** — for Sieve script processing. This copy allows you to run custom scripts on each message (webhook notifications, verification code extraction, Mailpit relay, etc.) without affecting Gmail delivery.

The local copy runs Sieve at delivery time. If you have no Sieve script configured, the local copy accumulates in the local mailbox (accessible via IMAP/POP3). To discard it after script processing, add `discard;` at the end of your Sieve script. To forward it to a web UI like Mailpit, use `redirect :copy "catchall@mailpit";` in your Sieve script.

```text
Incoming mail → Postfix
  ├── FORWARD_TO → Gmail (primary inbox)
  └── CATCHALL → Dovecot LMTP → Sieve
        ├── PROCESSOR_SCRIPT (webhook, notification, code extraction)
        ├── redirect :copy → Mailpit (optional web UI)
        └── keep / discard (user's choice)
```

This approach:

- Maintains the catchall server's ability to receive mail for multiple domains/aliases
- Leverages Gmail's infrastructure for email storage and retrieval
- Requires no special Gmail authentication or app passwords
- Enables local script automation without a separate mail processing pipeline
- Keeps setup simple: one `FORWARD_TO` env var, optional Sieve for automation

## Prerequisites

You will need:

1. A Gmail account (or Google Workspace account) to receive the forwarded mail
2. Domain(s) that can have DNS records modified (for SPF/DMARC)
3. The catchall container deployed and receiving mail

## Step 1: Set Up DNS Records

Add the following records to your domain's DNS for authentication. These help Gmail trust that your mail server is legitimate.

### SPF Record

Add a TXT record to your domain:

```txt
v=spf1 ip4:YOUR.SERVER.IP.ADDRESS ~all
```

Replace `YOUR.SERVER.IP.ADDRESS` with your mail server's public IP address. This tells Gmail (and other receivers) that this IP is authorized to send mail for your domain.

**Note:** If you have an existing SPF record, add `ip4:YOUR.SERVER.IP.ADDRESS` to it instead of replacing it.

### DMARC Record (Recommended)

Add a TXT record to `_dmarc.yourdomain.com`:

```txt
v=DMARC1; p=quarantine; rua=mailto:admin@yourdomain.com
```

This tells Gmail how to handle messages that fail authentication checks.

**Note:** DNS propagation can take 24-48 hours. Proceed to configuration, but SPF/DMARC checks may fail until records are live.

## Step 2: Configure Container

Set these environment variables:

```bash
-e DOMAIN="yourdomain.com"
-e HOSTNAME="mail.yourdomain.com"
-e FORWARD_TO="your-email@gmail.com"
```

The init script automatically configures Postfix to forward all mail to your Gmail address.

**For more advanced configuration** (spam filtering with `DEVNULL`, domain aliases with `ALIASES`, email processing scripts), see [EXAMPLE.md](EXAMPLE.md).

## Step 3: Test Email Forwarding

Send a test email to your catchall server and check Gmail for delivery. View the message headers:

- **SPF**: Should show `PASS` (if DNS record is live)
- **DKIM**: Shows `PASS` only if DKIM signing is enabled (see [DKIM.md](DKIM.md))
- **DMARC**: Usually `PASS` if SPF passes

If headers show failures, verify your DNS SPF record is live with [MXToolbox SPF Check](https://mxtoolbox.com/spf.aspx).

## Troubleshooting

### Emails Not Reaching Gmail

1. **Check container is running:**

   ```bash
   docker ps | grep catchall
   ```

2. **Verify SPF record is live:**

   ```bash
   dig yourdomain.com TXT | grep spf
   ```

   Or use [MXToolbox SPF Check](https://mxtoolbox.com/spf.aspx).

3. **Check DNS propagation (may take 24-48 hours)**

### SPF Check Failures

- **SPF record missing**: Verify `v=spf1 ip4:YOUR.IP.ADDRESS ~all` is added to DNS
- **Wrong IP address**: Confirm you're using your mail server's actual public IP
- **Record not propagated**: DNS changes take 24-48 hours; check with `dig yourdomain.com TXT`

### Email Headers Show DKIM Issues

- **DKIM FAIL or missing**: DKIM is optional. Enable it for better deliverability (see [DKIM.md](DKIM.md))
- **Forwarded mail failing downstream**: Enable DKIM signing so signatures survive Gmail's forwarding (see **Important Limitations** section below)

## Step 4: Organize Emails in Gmail (Optional)

Once emails arrive in Gmail, set up labels and filters:

1. **Create labels** for different catchall addresses or domains
2. **Set up Gmail filters**:
   - Filter: `to:catchall@yourdomain.com`
   - Action: Apply label "Catchall"
   - Optionally skip inbox

This keeps your main Gmail inbox organized.

## Important Limitations

### SPF Failures When Forwarding

When your catchall server forwards mail to Gmail, **SPF checks will fail** for the forwarded messages. Here is why:

1. Your catchall server receives `sender@example.com`'s email
2. Your server relays it to Gmail with envelope sender `sender@example.com`
3. Gmail sees: SMTP connection from **your server's IP**, envelope sender **`sender@example.com`**
4. Gmail checks SPF for `example.com` — your server's IP is not listed → **SPF FAIL/SOFTFAIL**

Your own SPF record (`v=spf1 ip4:YOUR.IP ~all`) authorizes your IP to send mail **from your domain**, not from other senders' domains. You cannot fix their SPF from your side.

**Gmail's leniency:** For small single-user volumes, Gmail is generally tolerant of forwarded mail with SPF failures and uses other signals (message history, ARC headers) to avoid misclassifying legitimate forwarded mail as spam. This means many users will see forwarded mail arrive cleanly even without additional configuration.

**Non-Gmail providers** (Outlook, Yahoo, corporate mail servers) are less forgiving and may reject or quarantine forwarded mail with SPF failures.

### What DKIM Signing Does (and Does Not) Fix

Enabling DKIM on your catchall server (see [docs/DKIM.md](DKIM.md)) signs **all outgoing mail** — including forwarded messages — with your domain's private key. The DKIM `d=` tag will be your domain regardless of the original `From:` address.

This adds a hop-level signature proving your server processed the message cleanly. It does **not** fix DMARC alignment for the original sender: DMARC alignment requires the `d=` tag to match the `From:` header domain, and forwarded mail from `sender@external.com` will have `d=yourdomain.com`. Your signature does not help the original sender's DMARC result.

What does survive forwarding intact: the **original sender's DKIM signature** (you are not modifying the message body). If the original sender signed with DKIM, their signature remains valid. You cannot control whether external senders use DKIM.

### Recommended Solution: ARC Signing

**ARC (Authenticated Received Chain, RFC 8617)** is the correct solution for forwarders. ARC seals the authentication state at each forwarding hop. Gmail evaluates the ARC chain and can pass forwarded mail even when the envelope sender's SPF fails.

OpenDKIM (version 2.11+) and the separate OpenARC daemon both support ARC signing. When implemented, your server adds ARC headers indicating what authentication checks passed at your hop, allowing Gmail to make a more informed trust decision.

ARC implementation is planned as a future feature. For most small-volume hobbyist deployments, Gmail's leniency makes ARC non-essential initially.

### Future: Sender Rewriting Scheme (SRS)

For strict RFC compliance and interoperability with non-Gmail providers, **PostSRSD** can rewrite envelope senders so your IP is authorized for the rewritten address:

- Rewrites `sender@original-domain` → `SRS0=hash=xx=original-domain=sender@catchall-domain`
- Your SPF record for `catchall-domain` covers the rewritten address
- Full SPF pass chain through the forwarding hop

This is important for forwarding to providers that enforce strict SPF. It is planned as a future feature.

## References

- [Postfix Virtual Alias Documentation](http://www.postfix.org/virtual.5.html)
- [DMARC Specification](https://tools.ietf.org/html/rfc7489)
- [SPF Specification](https://tools.ietf.org/html/rfc7208)

## Optional: DKIM Signing

For higher email volumes or stricter authentication requirements, enable DKIM signing. See [docs/DKIM.md](DKIM.md) for setup instructions.
