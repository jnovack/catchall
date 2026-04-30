#!/usr/bin/env bats
# Unit tests for rootfs/etc/cont-init.d/10-postfix-init
# Covers FORWARD_TO/CATCHALL routing logic, DEVNULL, and alias domain handling.
# The `ip` command from iproute2 is installed in the test image and returns
# real routes; postconf/postmap/postalias are stubbed.

load "setup"

SCRIPT=/scripts/10-postfix-init

# ---------------------------------------------------------------------------
# Forwarding mode
# ---------------------------------------------------------------------------

@test "Postfix: FORWARD_TO unset: mail is stored locally only" {
    export DOMAIN="contoso.com"
    export CATCHALL="catchall"
    unset FORWARD_TO
    unset ALIASES
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"No forwarding configured"* ]]
    # catch-all maps to local account only (no external address)
    grep -qE "^@contoso\.com[[:space:]]+catchall$" /etc/postfix/virtual
}

@test "Postfix: FORWARD_TO set: mail delivered to both external and local catchall" {
    export DOMAIN="contoso.com"
    export CATCHALL="catchall"
    export FORWARD_TO="user@gmail.com"
    unset ALIASES
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Forwarding enabled: user@gmail.com"* ]]
    # catch-all maps to FORWARD_TO and local catchall
    grep -qE "^@contoso\.com[[:space:]]+user@gmail\.com, catchall$" /etc/postfix/virtual
}

@test "Postfix: CATCHALL defaults to 'catchall' when not set" {
    export DOMAIN="contoso.com"
    unset CATCHALL
    unset FORWARD_TO
    unset ALIASES
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Local copy: catchall"* ]] || \
        grep -qE "^@contoso\.com[[:space:]]+catchall$" /etc/postfix/virtual
}

# ---------------------------------------------------------------------------
# DEVNULL: reject-at-RCPT addresses
# ---------------------------------------------------------------------------

@test "Postfix: DEVNULL address is rejected via recipient_access" {
    export DOMAIN="contoso.com"
    export CATCHALL="catchall"
    export DEVNULL="spam@contoso.com"
    unset FORWARD_TO
    unset ALIASES
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"DEVNULL: spam@contoso.com"* ]]
    grep -qE "^spam@contoso\.com[[:space:]]+550 5\.1\.1 Recipient address rejected$" /etc/postfix/recipient_access
}

@test "Postfix: multiple DEVNULL addresses are all rejected via recipient_access" {
    export DOMAIN="contoso.com"
    export CATCHALL="catchall"
    export DEVNULL="spam@contoso.com webmaster@contoso.com"
    unset FORWARD_TO
    unset ALIASES
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -qE "^spam@contoso\.com[[:space:]]+550 5\.1\.1 Recipient address rejected$" /etc/postfix/recipient_access
    grep -qE "^webmaster@contoso\.com[[:space:]]+550 5\.1\.1 Recipient address rejected$" /etc/postfix/recipient_access
}

@test "Postfix: noreply@DOMAIN is always rejected via recipient_access" {
    export DOMAIN="contoso.com"
    export CATCHALL="catchall"
    unset FORWARD_TO
    unset ALIASES
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -qE "^noreply@contoso\.com[[:space:]]+550 5\.1\.1 Recipient address rejected$" /etc/postfix/recipient_access
}

# ---------------------------------------------------------------------------
# Alias domains
# ---------------------------------------------------------------------------

@test "Postfix: alias domain gets its own catch-all entry" {
    export DOMAIN="contoso.com"
    export CATCHALL="catchall"
    export ALIASES="fabrikam.com"
    unset FORWARD_TO
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"ALIAS domain: fabrikam.com"* ]]
    grep -qE "^@fabrikam\.com" /etc/postfix/virtual
    grep -qE "^noreply@fabrikam\.com[[:space:]]+550 5\.1\.1 Recipient address rejected$" /etc/postfix/recipient_access
}

# ---------------------------------------------------------------------------
# Postfix configuration calls
# ---------------------------------------------------------------------------

@test "Postfix: postconf is called for myhostname, mydomain, virtual_alias_domains" {
    export DOMAIN="contoso.com"
    export CATCHALL="catchall"
    unset FORWARD_TO
    unset ALIASES
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q "myhostname=" "${STUB_LOG}"
    grep -q "mydomain=" "${STUB_LOG}"
    grep -q "virtual_alias_domains=" "${STUB_LOG}"
}

@test "Postfix: postmap is called on the virtual and recipient access maps" {
    export DOMAIN="contoso.com"
    export CATCHALL="catchall"
    unset FORWARD_TO
    unset ALIASES
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q "postmap /etc/postfix/virtual" "${STUB_LOG}"
    grep -q "postmap /etc/postfix/recipient_access" "${STUB_LOG}"
}

@test "Postfix: exits 0 with minimal env (domain only)" {
    export DOMAIN="contoso.com"
    unset CATCHALL FORWARD_TO ALIASES DEVNULL
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
}
