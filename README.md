# catchall

[![Docker](https://badgen.net/badge/jnovack/catchall/blue?icon=docker)](https://hub.docker.com/r/jnovack/catchall)
[![Github](https://badgen.net/badge/jnovack/catchall/purple?icon=github)](https://github.com/jnovack/catchall)

**catchall** is a simple all-in-one mail server for catching all email and
funnelling it to a single catchall address which is available for pickup.

## Overview

Use as your own personal "mailinator" or simply because you want tons of
throw-away email addresses when throw-away domains are not permitted.

This is *not* another SquirrelMail or Roundcube replacement.  I wanted minimal
setup and container portability for a single user to receive email at multiple
throw-away addresses for throw-away services.

## Features

- All-in-One SMTP server (receiving) and POP3/IMAP server (retrieving)
- Docker Secrets compatibility
- Provides TLS services by leveraging Let's Encrypt as a sidecar
- Automagic restart when new certificates are found

### Not Supported (Yet)

- HTTP UI / API

My first goal was to get emails available for pickup and import by other
services (Gmail, specifically).  Providing a web-based UI or API means
additional processes (which there already are a lot), and databases to keep
consistent with the mail spool on disk.

- Sending email

This was just designed as a "mailinator"-clone, so I have not implemented
sending emails.

## Environment Variables

### ALIASES

Space-separated list of alias domains to also receive mail.

```sh
ALIASES="contoso.home fabrikam.com"
```
### CATCHALL

The name of your catchall account.  All emails (not sent to `/dev/null`) will
be aggregated and forwarded to this account.

```sh
# default
CATCHALL=catchall
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

Hostname to present.  This MUST match the Common Name on your SSL certificate.

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
SLACK_URL_FILE="https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX
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
