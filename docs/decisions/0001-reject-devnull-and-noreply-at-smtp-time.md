# ADR 0001: Reject `DEVNULL` and `noreply` Recipients at SMTP Time

- Status: Accepted
- Date: 2026-04-30

## Context

Catchall supports two classes of intentionally non-deliverable recipients:

- addresses listed in `DEVNULL`
- implicit `noreply@DOMAIN` and `noreply@ALIASES`

Before this decision, `10-postfix-init` wrote those recipients to
`/etc/postfix/virtual` as `nobody`, and also generated a Postfix alias:

```text
nobody: /dev/null
```

That approach no longer matched the runtime architecture.

Postfix is configured with:

- `virtual_transport = lmtp:unix:private/dovecot-lmtp`
- `local_transport = lmtp:unix:private/dovecot-lmtp`

As a result, mail addressed to `nobody` was handed to Dovecot LMTP instead of
being discarded by Postfix. Dovecot then resolved the passwd entry for `nobody`
and attempted delivery using that account's home directory, typically
`/nonexistent`.

In live traffic this produced delivery-time errors such as:

- duplicate database lock failures under `/nonexistent`
- mailbox autocreation failures under `/nonexistent/mail`
- aborted Sieve execution

This had three practical problems:

1. Burned recipients were not actually rejected or discarded at the SMTP edge.
2. The server accepted spam for those recipients and only failed later in local delivery.
3. The logs were noisy and misleading for operators, and the accept-then-fail path
   increased backscatter risk for forged sender spam.

## Decision

Catchall will reject `DEVNULL` and implicit `noreply` recipients during the
SMTP `RCPT TO` stage.

Implementation rules:

- `10-postfix-init` writes those recipients to
  `/etc/postfix/recipient_access`.
- The access map uses a permanent reject action:
  `550 5.1.1 Recipient address rejected`.
- `rootfs/etc/postfix/main.cf` enforces the map with:
  `check_recipient_access hash:/etc/postfix/recipient_access`
  near the top of `smtpd_recipient_restrictions`.
- The old `nobody` virtual alias mapping is removed.
- The old `nobody: /dev/null` alias is removed.

This decision applies to:

- every address listed in `DEVNULL`
- `noreply@${DOMAIN}`
- `noreply@${ALIASES}`

Normal catch-all routing remains unchanged for all other recipients.

## Consequences

### Positive

- Dovecot LMTP never sees intentionally blackholed recipients.
- `/nonexistent` mailbox and Sieve errors disappear for this case.
- The server does not accept mail it already knows it does not want.
- Backscatter risk is reduced because the failure is returned to the SMTP client
  during the session.
- Operator behavior matches documentation: burned recipients are blocked at the edge.

### Tradeoffs

- Remote senders now receive an explicit `5xx` instead of a silent accept-and-drop.
- SMTP test fixtures must preserve `check_recipient_access` when relaxing other
  restrictions for isolated Docker networking.

## Alternatives Considered

### 1. Keep mapping to `nobody`

Rejected.

This no longer works with the current Postfix-to-Dovecot LMTP delivery model.
The alias does not short-circuit delivery before LMTP, so the message is not
actually blackholed.

### 2. Accept then discard locally

Rejected.

This would preserve silent behavior for the sender, but Catchall would still
accept spam for burned recipients. The project goal for these addresses is to
avoid local acceptance of obvious garbage, not to process it quietly after the fact.

### 3. Temporary failure or tarpitting

Rejected.

`4xx` responses and delay tactics increase retries and operational noise without
solving the underlying problem better than a permanent reject.

## Validation

The decision is enforced by both unit and end-to-end coverage:

- unit tests verify `recipient_access` generation and `postmap` execution
- the forwarding/DKIM compose suite verifies a `550 5.1.1` response during
  `RCPT TO` and confirms the message is not delivered to Mailpit

## References

- [rootfs/etc/cont-init.d/10-postfix-init](../../rootfs/etc/cont-init.d/10-postfix-init)
- [rootfs/etc/postfix/main.cf](../../rootfs/etc/postfix/main.cf)
- [test/unit/postfix.bats](../../test/unit/postfix.bats)
- [test/dkim/entrypoint.sh](../../test/dkim/entrypoint.sh)
- [README.md](../../README.md)
