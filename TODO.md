# TODO

## Stupid Verizon doesn't update DNS

The rejecting rule is:

`reject_unknown_helo_hostname` in `smtpd_helo_restrictions`

See main.cf (line 25)

Your log message maps directly to it:

```text
Helo command rejected: Host not found
helo=<wlnecrmsmtp01.verizon.com>
```

So Postfix looked up that HELO name and couldn’t validate it (at least at that moment), then returned 450 4.7.1.

And yes, even big senders do this sometimes (bad HELO host, stale DNS, temporary DNS failure, or inconsistent outbound pools).

If you want to be less strict, the smallest safe change is to drop only this check:

```text
smtpd_helo_restrictions = permit_mynetworks, reject_invalid_helo_hostname, reject_non_fqdn_helo_hostname
```

Or keep strict policy and whitelist specific known sender IPs separately.

Pragmatic middle ground:

Keep reject_invalid_helo_hostname and reject_non_fqdn_helo_hostname.
Remove only reject_unknown_helo_hostname.
Rely on your RBL/RHSBL checks and downstream filtering for the rest.
