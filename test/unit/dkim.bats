#!/usr/bin/env bats
# Unit tests for rootfs/etc/cont-init.d/08-dkim-init
# Tests invoke the script directly via bash to bypass the with-contenv shebang.
# s6 env injection is replaced by explicit export in each test.

load "setup"

SCRIPT=/scripts/08-dkim-init

# ---------------------------------------------------------------------------
# Feature gating
# ---------------------------------------------------------------------------

@test "DKIM: exits 0 and skips when DKIM_DOMAIN is unset" {
    unset DKIM_DOMAIN
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"[INFO  ] DKIM not configured; skipping"* ]]
    # postconf must not have been invoked
    [ ! -f "${STUB_LOG}" ] || ! grep -q "postconf" "${STUB_LOG}"
}

@test "DKIM: exits 0 and skips when DKIM_DOMAIN is empty" {
    export DKIM_DOMAIN=""
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"[INFO  ] DKIM not configured; skipping"* ]]
}

# ---------------------------------------------------------------------------
# Key resolution: missing key
# ---------------------------------------------------------------------------

@test "DKIM: exits 1 when DKIM_DOMAIN set but no key is provided" {
    export DKIM_DOMAIN="example.com"
    unset DKIM_PRIVATE_KEY
    unset DKIM_PRIVATE_KEY_FILE
    run bash "${SCRIPT}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"[ERROR ]"* ]]
}

@test "DKIM: exits 1 when DKIM_PRIVATE_KEY_FILE path does not exist and DKIM_PRIVATE_KEY is unset" {
    export DKIM_DOMAIN="example.com"
    export DKIM_PRIVATE_KEY_FILE="/nonexistent/does-not-exist.key"
    unset DKIM_PRIVATE_KEY
    run bash "${SCRIPT}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"[ERROR ]"* ]]
}

# ---------------------------------------------------------------------------
# Key resolution: _FILE precedence over bare env
# ---------------------------------------------------------------------------

@test "DKIM: DKIM_PRIVATE_KEY_FILE takes precedence over DKIM_PRIVATE_KEY" {
    export DKIM_DOMAIN="example.com"
    export DKIM_PRIVATE_KEY_FILE="${TEST_KEY_FILE}"
    export DKIM_PRIVATE_KEY="this-should-not-be-used"
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Loading private key from ${TEST_KEY_FILE}"* ]]
    [[ "${output}" != *"Loading private key from DKIM_PRIVATE_KEY env"* ]]
}

@test "DKIM: falls back to DKIM_PRIVATE_KEY when DKIM_PRIVATE_KEY_FILE path does not exist" {
    export DKIM_DOMAIN="example.com"
    export DKIM_PRIVATE_KEY_FILE="/nonexistent/does-not-exist.key"
    export DKIM_PRIVATE_KEY="$(cat "${TEST_KEY_FILE}")"
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Loading private key from DKIM_PRIVATE_KEY env"* ]]
}

@test "DKIM: uses DKIM_PRIVATE_KEY env when no DKIM_PRIVATE_KEY_FILE is set" {
    export DKIM_DOMAIN="example.com"
    unset DKIM_PRIVATE_KEY_FILE
    export DKIM_PRIVATE_KEY="$(cat "${TEST_KEY_FILE}")"
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Loading private key from DKIM_PRIVATE_KEY env"* ]]
}

# ---------------------------------------------------------------------------
# Selector defaults and overrides
# ---------------------------------------------------------------------------

@test "DKIM: DKIM_SELECTOR defaults to 'default' when not set" {
    export DKIM_DOMAIN="example.com"
    export DKIM_PRIVATE_KEY_FILE="${TEST_KEY_FILE}"
    unset DKIM_SELECTOR
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"DKIM selector: default"* ]]
}

@test "DKIM: custom DKIM_SELECTOR is used when set" {
    export DKIM_DOMAIN="example.com"
    export DKIM_PRIVATE_KEY_FILE="${TEST_KEY_FILE}"
    export DKIM_SELECTOR="mail2024"
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"DKIM selector: mail2024"* ]]
}

# ---------------------------------------------------------------------------
# Runtime marker and Postfix milter config
# ---------------------------------------------------------------------------

@test "DKIM: /run/opendkim directory is created when DKIM is configured" {
    export DKIM_DOMAIN="example.com"
    export DKIM_PRIVATE_KEY_FILE="${TEST_KEY_FILE}"
    rm -rf /run/opendkim
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ -d /run/opendkim ]
}

@test "DKIM: postconf is called with milter settings when DKIM is configured" {
    export DKIM_DOMAIN="example.com"
    export DKIM_PRIVATE_KEY_FILE="${TEST_KEY_FILE}"
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    grep -q "smtpd_milters" "${STUB_LOG}"
    grep -q "non_smtpd_milters" "${STUB_LOG}"
}

@test "DKIM: postconf is NOT called when DKIM_DOMAIN is unset" {
    unset DKIM_DOMAIN
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [ ! -f "${STUB_LOG}" ] || ! grep -q "postconf" "${STUB_LOG}"
}

# ---------------------------------------------------------------------------
# DNS validation: non-fatal when unreachable
# ---------------------------------------------------------------------------

@test "DKIM: DNS validation failure is non-fatal (warns and continues)" {
    export DKIM_DOMAIN="example.com"
    export DKIM_PRIVATE_KEY_FILE="${TEST_KEY_FILE}"
    # curl stub returns empty → triggers the "Could not reach DNS resolver" warn path
    run bash "${SCRIPT}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"[WARN  ]"* ]]
    [[ "${output}" == *"DKIM configuration complete"* ]]
}
