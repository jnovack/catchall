# catchall

[![Docker](https://badgen.net/badge/jnovack/catchall/blue?icon=docker)](https://hub.docker.com/r/jnovack/catchall)
[![Github](https://badgen.net/badge/jnovack/catchall/purple?icon=github)](https://github.com/jnovack/catchall)

**catchall** is a ~~simple~~ all-in-one mail server for catching all email and
funnelling it to a single catchall address which is available for pickup for forwarding.

## Overview

Use as your own personal "mailinator" — receive mail at any address on your domain and
forward it automatically to Gmail (or another inbox). Create as many throw-away addresses
as you need; kill specific ones when they get sold to marketers by adding them to `DEVNULL`.

This is *not* a SquirrelMail or Roundcube replacement. It is designed for minimal setup
and single-user operation.

## Features

- **Catch-all SMTP Receiver** (port 25): Accepts all mail for your domain(s)
- **STARTTLS**: Opportunistic TLS on port 25 for inbound and outbound SMTP
- **Mail Forwarding**: Automatically relays received mail to your external account (e.g. Gmail)
- **DKIM signing** (optional): Signs all outgoing mail with your domain's private key
- **Per-address kill-switch**: Add burned addresses to `DEVNULL` to drop their mail silently
- **Multi-domain support**: Accept mail for multiple domains via `ALIASES`
- **Sieve filtering**: Optional per-user and global email filter scripts
- **Local mailbox** (optional): IMAP/POP3 via Dovecot if you prefer local storage over forwarding
- **Docker Secrets compatibility**
- **Let's Encrypt TLS** with automatic certificate reload (Dovecot + Postfix)

### Not Supported / Out of Scope

#### HTTP UI / API

If you would like, you can easily add [axllent/mailpit](https://mailpit.axllent.org/) to the stack,
see [docs/FORWARDER.md](docs/FORWARDER.md) for details.

#### Sending Email

This is a receive-and-forward container, not a user-facing MTA.

## Environment Variables

### ALIASES

Space-separated list of alias domains to also receive mail.

```sh
ALIASES="contoso.home fabrikam.com"
```

### CATCHALL

Local account name for receiving emails (stored in Dovecot). When forwarding is not configured, mail is delivered to this local account.

```sh
# default
CATCHALL=catchall
```

### FORWARD_TO

**Optional:** Gmail address (or other external address) to forward all received emails. If not set, emails are delivered to the local `CATCHALL` account instead.

```sh
FORWARD_TO="your-email@gmail.com"
```

### DEVNULL

Space-separated list of email addresses to send to `/dev/null`.

```sh
DEVNULL="sales@contoso.com noreply@contoso.com"
```

### DOMAIN

Primary domain to accept email.

```sh
DOMAIN="contoso.com"
```

### HOSTNAME

Hostname to present.

> [!WARNING]
> This **MUST** match the Common Name on your SSL certificate.

```sh
HOSTNAME="mail.contoso.com"
```

### PASSWORD (or PASSWORD_FILE)

Set the password for your catchall account.

If you do not specify a password (or password_file), the container will
automatically generate a very complex and secure one for you and print to the
console.

```sh
PASSWORD="hunter2"
# or
PASSWORD_FILE="/run/secrets/catchall-password"
```

### SLACK_URL_FILE

When certbot successfully renews a certificate, you can be sent a slack
notification as confirmation.

```sh
SLACK_URL_FILE="https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
```

### STARTUP_DELAY

Number of 2-second iterations to wait for certificates before failing startup.

```sh
# default
STARTUP_DELAY=5
```

### TIMEZONE

`tz`-compatable timezone for log files and timestamping.  Please see the
[list of tz database time zones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).

```sh
# default
TIMEZONE="Etc/UTC"
```

### DKIM_DOMAIN

Primary domain for DKIM signing. When set, all outgoing mail is signed with your domain's
private key via OpenDKIM. Requires `DKIM_PRIVATE_KEY` or `DKIM_PRIVATE_KEY_FILE`.

```sh
DKIM_DOMAIN="contoso.com"
```

### DKIM_SELECTOR

DKIM selector name. Must match the selector in your DNS TXT record (`<selector>._domainkey.<domain>`).

```sh
# default
DKIM_SELECTOR=default
```

### DKIM_PRIVATE_KEY (or DKIM_PRIVATE_KEY_FILE)

The RSA private key for DKIM signing. Pass inline or via Docker Secret.

```sh
DKIM_PRIVATE_KEY_FILE="/run/secrets/dkim-private-key"
```

See [docs/DKIM.md](docs/DKIM.md) for key generation and DNS setup instructions.

### SIEVE (or SIEVE_FILE)

Optional per-user Sieve script for the catchall account. Runs at delivery time inside
Dovecot and can forward, discard, file to folders, or pipe to external scripts.

```sh
# Inline Sieve script
# send it to the Archive folder in Dovecot
SIEVE="require [\"fileinto\"]; fileinto \"Archive\";"
# or to send it to another server (e.g. like Mailpit)
SIEVE="redirect :copy \"catchall@mailpit\";"
# or drop it.
SIEVE="discard;"

# From Docker Secret
SIEVE_FILE="/run/secrets/catchall-sieve"
```

### GLOBAL_SIEVE (or GLOBAL_SIEVE_FILE)

Optional global Sieve script that runs **before** the per-user script for all delivered
messages. Useful for applying organization-wide filtering rules.

```sh
# Inline global Sieve
GLOBAL_SIEVE="if header :contains \"X-Spam-Flag\" \"YES\" { discard; stop; }"

# From Docker Secret
GLOBAL_SIEVE_FILE="/run/secrets/global-sieve"
```

### PROCESSOR_SCRIPT (or PROCESSOR_SCRIPT_FILE or PROCESSOR_SCRIPT_URL)

Optional email processing script. When set, a copy of each incoming email is piped to your script for custom processing (webhooks, logging, notifications, etc.). The Sieve processor uses one of three input methods:

1. **PROCESSOR_SCRIPT**: Inline script (shell commands or shebang)
2. **PROCESSOR_SCRIPT_FILE**: Path to script file (Docker Secret)
3. **PROCESSOR_SCRIPT_URL**: Download script from URL at startup

> [!CAUTION]
> `PROCESSOR_SCRIPT_URL` executes remote code at startup and should only be used with trusted, pinned sources.

Examples:

```sh
# Inline webhook notification
PROCESSOR_SCRIPT="#!/bin/sh
curl -X POST https://webhooks.example.com/mail -d @-"

# From Docker Secret
PROCESSOR_SCRIPT_FILE="/run/secrets/mail-processor.sh"

# Download at startup
PROCESSOR_SCRIPT_URL="https://example.com/processor.sh"
```

For detailed examples (logging, JSON output, Gmail integration), see [docs/EXAMPLE.md](docs/EXAMPLE.md).
