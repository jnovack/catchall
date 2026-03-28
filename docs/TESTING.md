# Testing

The file `docker-compose.test.yml` is specific to Docker Hub to perform
[automated repository tests](https://docs.docker.com/docker-hub/builds/automated-testing/),
but we can use the file in the same manner to perform local testing.  It also
serves as an example for a complete end-to-end working environment without
having to compromise a server or your own keys for testing.

In an effort to teach, grow and "level-up", I will try my best to explain the
commands and the reasons behind them.  This should make it easier for someone
to correct my testing (in the event I am doing it wrong), or make it easier for
someone to utilize these ideas in a future project.

## Terminology

> The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
> "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
> document are to be interpreted as described in BCP 14,
> [RFC2119](https://tools.ietf.org/html/rfc2119).

## Test suites

The project has two end-to-end test suites, both using Docker Compose with `--exit-code-from sut`.

### Main suite (`make sut`)

Validates local-only mode: no forwarding, no DKIM.

```bash
make sut
# or directly:
docker-compose -f docker-compose.test.yml up --exit-code-from sut
```

Checks:

1. SMTP delivery → Postfix → Dovecot LMTP → Sieve → POP3 retrieval
2. Message headers and body content
3. Sieve script execution (verification code capture)
4. STARTTLS advertised in EHLO and TLS handshake verified

### Forwarding suite (`make test-forward`)

Validates forwarding + DKIM mode: `FORWARD_TO`, `DKIM_DOMAIN`, and all related features.

```bash
make test-forward
# or directly:
docker-compose -f docker-compose.forward-test.yml up --exit-code-from sut
```

Checks:

1. Mailpit (the "external" destination) received the forwarded message
2. Verification code present in the Mailpit copy
3. Local Dovecot copy also received (dual delivery)
4. Sieve script executed on the local copy
5. DEVNULL address silently dropped
6. DKIM-Signature header present in the forwarded message
7. STARTTLS advertised in EHLO and TLS handshake verified

### Cleanup targets

```bash
make nuke           # tear down all suite containers and volumes
```

## Local quick testing

For fast iteration:

```bash
docker build -t catchall:test .
docker run -it catchall:test /bin/sh
```

Run a container with feature flags for targeted validation:

```bash
docker run -it \
  -e FEATURE=value \
  -e DOMAIN=test.local \
  catchall:test
```

Inspect logs for feature behavior:

```bash
docker logs CONTAINER | grep FEATURE
```

## Feature testing workflow

For new optional features, cover three paths:

1. Disabled path — run the normal suite without feature env vars; existing behavior must remain unchanged.
2. Enabled path — run with the feature configured and verify the expected mail flow behavior.
3. Error path — run with invalid or missing supporting config and confirm the feature skips safely without crashing the container.

## Validation guidance

- Start with the smallest relevant verification step.
- Use the full SUT suite when a change touches mail flow, startup sequencing, or cross-service behavior.
- If no automated test exists, document a lightweight manual verification path.
- Never claim a test passed unless it was actually run.

## Useful commands

Run the full suite and keep the SUT attached:

```bash
docker-compose -f docker-compose.test.yml up --exit-code-from sut --attach sut
```

Inspect server logs during testing:

```bash
docker-compose -f docker-compose.test.yml logs -f server
```

Tear down the test stack:

```bash
docker-compose -f docker-compose.test.yml down
```

## Services

Docker Hub only starts the `sut` service (stands for "System Under Test") and
any other services listed under `depends_on` for this service. Since
`depends_on` works backwards, we have `sut` start all of the other services.

Additionally, Docker Hub (and `make docker-test`) test for the exit condition
of the `sut` container; so we have it exit successfully (`0`) when we have a
successful test.  At that point we are sure that our `catchall` container
(which is the `server` service) is working.  We fail the test on any other exit
code.

We cannot test the `catchall` container within the context of itself as we have
no mechanism to do so.  We must test it externally, but, more importantly, we
SHOULD test it externally. This means we need an client container if we want to
be a valid test.

### bootloader

The purpose of the `bootloader` container is to create the certificate and
stage the environment.  This container takes the place of the
[certbot](https://hub.docker.com/r/certbot/certbot/) container and sets up any
customization that I would be testing for (such as Docker Secrets).

The `bootloader` service does not exit after it is complete because using
`--exit-code-from sut` implies `--abort-on-container-exit`.  This means the
`bootloader` service will have to hang around for some time.  I specifically
chose not to use `tail -f /dev/null` or something running indefinitely because
I wanted to fail out at SOME point.  I wanted a timeout.  By using `sleep 300`
it gives me 5 minutes (which is probably WAAAY too long) to run my test before
this container exits and thus fails the test.

If everything is good, this container SHOULD NOT hit `exit 99` but SHOULD be
shut down (`SIGTERM`) by `docker-compose`.

### sut

In order to properly test, we have to test both (a) sending an email, and (b)
receiving that email.  Rather than install an MTA, and rely on DNS
modification, which all seems messy, the easiest way to do that is to connect
to the socket directly and send a message.

We have our first problem, any of these services could not have started yet.
Since all the services are in different threads, there is effectively a race
condition to see who starts first.  We have to make sure that that ports (both
smtp and pop3s) are up before sending data to them an failing.

Thankfully, our new friend `nc` (`netcat`) comes to the rescue.  The `-z`
option checks to see if the remote port is up and answering.  So, we will loop
while the port is closed, and when it finally opens, we continue processing.

BUT, sending via SMTP has one huge caveat.  In the postfix configuration,
`reject_unauth_pipelining` is turned on, which means that any client MUST wait
for a response before sending the next command.  It hinders a lot of scripts
that fire-and-forget and reduces spam.  Once again, `nc` (or `netcat`) for the
win, it has an option (`-i`) to send lines from a text file at a minimum
interval!

So, we dump all of our commands to a separate file, then send each of them
slowly, with a delay, but only after we confirm the port is up and open.

We do this for both smtp and pop3. Finally, we check for a "unique-ish" string
that we send via smtp to confirm it is in our emails received via pop3.
