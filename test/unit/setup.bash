#!/usr/bin/env bash
# Shared setup and teardown for all unit test files.
# Load with:  load "setup"  (bats resolves relative to the test file's dir)

# The init scripts use #!/command/with-contenv bash (s6 shebang).
# In unit tests we invoke them directly via `bash /scripts/<name>` which
# bypasses the shebang. s6 env injection is replaced by explicit `export`
# statements in each test case.

setup() {
    # Fresh stub-call log per test
    STUB_LOG="$(mktemp)"
    export STUB_LOG

    # Real RSA key for tests that supply a key file
    TEST_KEY_FILE="$(mktemp --suffix=.key)"
    export TEST_KEY_FILE
    openssl genrsa -out "${TEST_KEY_FILE}" 2048 2>/dev/null

    # Directories that init scripts write to (pre-created in Dockerfile;
    # recreated here in case a previous test removed them)
    mkdir -p /etc/opendkim/keys /etc/postfix /run/opendkim
    : > /etc/postfix/main.cf
}

teardown() {
    # Remove per-test artifacts; use -f so missing files are not errors
    rm -f "${STUB_LOG}" "${TEST_KEY_FILE}"

    # DKIM artefacts
    rm -f /etc/opendkim/keytable /etc/opendkim/signingtable
    rm -f /etc/opendkim/keys/*.key
    rm -rf /run/opendkim

    # Postfix artefacts
    rm -f /etc/postfix/virtual /etc/postfix/virtual.db /etc/postfix/recipient_access /etc/postfix/recipient_access.db /etc/postfix/aliases /etc/postfix/main.cf
}
