# ADR 0002: Reject ARC for Now and Standardize on SRS + DKIM

- Status: Accepted
- Date: 2026-04-30

## Context

Catchall is a self-hosted forwarding container for hobbyist operators. The
project values are:

- minimal operator burden
- standard Ubuntu packages where possible
- optional features that fail safely
- small runtime footprint
- reproducible image builds

Forwarded mail has an authentication problem: SPF fails for the original sender
after the forwarding hop unless the envelope sender is rewritten. DKIM helps,
but DKIM alone does not solve every forwarding case.

ARC (Authenticated Received Chain, RFC 8617) was investigated as a possible
solution for forwarding deliverability. The practical question was whether ARC
could be added to this image without violating the simplicity and maintenance
constraints of the project.

## Findings

The ARC investigation found no acceptable implementation path for this repo.

### Option 1: Ubuntu-packaged `openarc`

Rejected because the package is not available in the Ubuntu archives used by
this project.

Observed package state:

- Ubuntu 24.04: `openarc` not available via `apt`
- Ubuntu 26.04: `openarc` not available via `apt`

### Option 2: OpenDKIM ARC mode

Rejected because the Ubuntu OpenDKIM build used by this project does not expose
ARC support.

Observed package state:

- `opendkim` is available in Ubuntu
- the shipped package build does not include usable ARC support

### Option 3: Build or vendor `openarc`

Rejected because it would transfer long-term maintenance to this project.

That path would require the repo to own:

- source build or vendored `.deb` packaging
- dependency compatibility across Ubuntu releases
- security tracking and rebuild cadence
- runtime integration and troubleshooting for unpackaged software

That is directly at odds with the project's operator profile and image design.

### Option 4: `rspamd` for ARC

Rejected because it is too heavy for this image.

Even though `rspamd` supports ARC, it introduces a much larger and more complex
 runtime footprint than Catchall is designed to carry. The repo has consistently
 treated low-memory, low-complexity deployment as a hard constraint.

### Option 5: Separate external gateway

Rejected for now because it changes the product boundary.

Running ARC in a separate gateway would avoid some in-image complexity, but it
would turn a single-container hobbyist deployment into a multi-service mail
architecture. That may be defensible later, but it is outside the current scope
of Catchall.

## Decision

Catchall will not implement ARC at this stage.

The project standard for forwarding authentication will be:

- DKIM signing for outbound and forwarded mail
- SRS for envelope-sender rewriting when forwarding is enabled

SRS + DKIM is the supported path because it addresses the actual forwarding
problem without introducing a new unpackaged daemon or a heavyweight mail stack.

## Consequences

### Positive

- Keeps the image aligned with the repo's simplicity goals
- Avoids source-built or vendored security-sensitive daemons
- Preserves a small operational footprint
- Focuses effort on one practical deliverability improvement path
- Keeps the forwarding story understandable for hobbyist operators

### Tradeoffs

- Catchall will not emit ARC headers
- Some forwarding scenarios may remain less robust than a full ARC-capable
  gateway
- Future ARC support would require a fresh architecture decision, not just an
  implementation patch

## What Replaces ARC

The supported roadmap is:

1. implement `postsrsd`
2. keep SRS optional and default-off
3. preserve current mail flow when SRS is disabled
4. document operator SPF requirements for the SRS domain

This gives the project a concrete, package-managed solution to forwarding SPF
failures while keeping the existing DKIM path intact.

## Rejected Reopen Criteria

This ADR intentionally rejects the earlier "defer and leave scaffolding in the
repo" approach. ARC-specific tests, stubs, and planning text are removed.

If ARC is ever reconsidered, it should start with a new ADR and a fresh
technical investigation based on then-current package availability and runtime
constraints.

## References

- [PLAN.md](../../PLAN.md)
- [TODO.md](../../TODO.md)
- [docs/FORWARDER.md](../FORWARDER.md)
- [docs/session-handoff.md](../session-handoff.md)
