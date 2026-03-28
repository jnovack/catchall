#!/bin/sh
set -e

trap exit TERM
CODE=$(awk 'BEGIN{srand(); print int(100000 + rand() * 899999)}')
echo "Verification Code: $CODE"

# ensure shared code file starts clean
rm -f /shared/code.txt

# ---- Wait for server SMTP ----
while :; do
  nc -z server 25 && break
  echo "waiting for smtp..."
  sleep 2 & wait $!
done

# ---- Send test email ----
cat <<EOF > /smtp.txt
EHLO fabrikam.home
mail from:<me@fabrikam.home>
rcpt to:fhqwhgads@contoso.local
data
Subject: Test Email
From: Test Sender <me@fabrikam.home>
To: fhqwhgads@contoso.local

Body of the email.
Verification Code $CODE

.
quit
EOF

echo "Sending test email..."
cat /smtp.txt
nc -i 1 server 25 < /smtp.txt

# ---- Wait for Mailpit to receive the forwarded copy ----
echo "Waiting for Mailpit to receive the forwarded email..."
TIMEOUT=30
ELAPSED=0
while :; do
  TOTAL=$(curl -sf http://mailsink:8025/api/v1/messages | grep -oE '"total":[0-9]+' | cut -d: -f2 || echo "0")
  [ "${TOTAL:-0}" -ge 1 ] && break
  ELAPSED=$((ELAPSED + 2))
  [ "${ELAPSED}" -ge "${TIMEOUT}" ] && echo "FAIL: Mailpit did not receive forwarded email within ${TIMEOUT}s" && exit 1
  echo "waiting for mailpit... (${ELAPSED}s)"
  sleep 2 & wait $!
done
echo "PASS: Mailpit received ${TOTAL} message(s)"

# ---- Verify message content in Mailpit ----
MSG_ID=$(curl -sf http://mailsink:8025/api/v1/messages | grep -oE '"ID":"[^"]+"' | head -1 | cut -d'"' -f4)
echo "Message ID: ${MSG_ID}"
MSG_SOURCE=$(curl -sf "http://mailsink:8025/api/v1/message/${MSG_ID}/raw")
echo "${MSG_SOURCE}" | grep -i "Verification Code ${CODE}" \
  || ( echo "FAIL: Verification code not found in Mailpit message source" && exit 1 )
echo "PASS: Verification code found in Mailpit message"

# ---- Verify local Dovecot copy via POP3 ----
while :; do
  nc -z server 995 && break
  echo "waiting for pop3..."
  sleep 2 & wait $!
done

cat <<EOF > /pop3.txt
USER catchall
PASS hunter2
LIST
RETR 1
DELE 1
QUIT
EOF

echo "Checking IMAP for messages, should be 1"
curl -u catchall:hunter2 --silent --insecure -k "imaps://server/INBOX" -X 'STATUS INBOX (MESSAGES)'

cat /pop3.txt | openssl s_client \
  -CAfile /etc/letsencrypt/live/mail.contoso.com/fullchain.pem \
  -quiet -servername mail.contoso.com -connect server:995 > /pop3-output.txt

echo "Checking IMAP for messages, should be 0"
curl -u catchall:hunter2 --silent --insecure -k "imaps://server/INBOX" -X 'STATUS INBOX (MESSAGES)'

echo "POP3 output:"
cat /pop3-output.txt

grep -E 'fhqwhgads@contoso.local' /pop3-output.txt \
  || ( echo "FAIL: 'rcpt to' was not found in POP3 output" && exit 1 )
grep -E -i "verification code ${CODE}" /pop3-output.txt \
  || ( echo "FAIL: 'verification code' was not found in POP3 output" && exit 1 )
echo "PASS: Local Dovecot copy verified via POP3"

# ---- Verify Sieve executed write-code.sh ----
WAIT=0
while [ ! -f /shared/code.txt ]; do
  WAIT=$((WAIT + 1))
  [ "${WAIT}" -ge 15 ] && echo "FAIL: Sieve did not create /shared/code.txt within 15s" && exit 1
  sleep 1 & wait $!
done
grep -Fx "$CODE" /shared/code.txt \
  || ( echo "FAIL: Sieve did not capture the expected verification code" && exit 1 )
echo "PASS: Sieve executed write-code.sh and captured the verification code"

# ---- Verify DEVNULL address is dropped ----
BEFORE_COUNT=$(curl -sf http://mailsink:8025/api/v1/messages | grep -oE '"total":[0-9]+' | cut -d: -f2 || echo "0")
echo "Mailpit count before DEVNULL test: ${BEFORE_COUNT}"

cat <<EOF > /devnull.txt
EHLO fabrikam.home
mail from:<me@fabrikam.home>
rcpt to:sales@contoso.com
data
Subject: This should be devnulled

This message should not be delivered anywhere.
.
quit
EOF

echo "Sending to DEVNULL address..."
nc -i 1 server 25 < /devnull.txt
sleep 5 & wait $!

AFTER_COUNT=$(curl -sf http://mailsink:8025/api/v1/messages | grep -oE '"total":[0-9]+' | cut -d: -f2 || echo "0")
echo "Mailpit count after DEVNULL test: ${AFTER_COUNT}"
[ "${BEFORE_COUNT}" -eq "${AFTER_COUNT}" ] \
  || ( echo "FAIL: DEVNULL address delivered to Mailpit (count changed ${BEFORE_COUNT} → ${AFTER_COUNT})" && exit 1 )
echo "PASS: DEVNULL address correctly dropped"

# ---- DKIM header check (when DKIM_DOMAIN is configured) ----
if [ -n "${DKIM_DOMAIN}" ]; then
  echo "Checking for DKIM-Signature in Mailpit message source..."
  echo "${MSG_SOURCE}" | grep -i "DKIM-Signature" \
    || ( echo "FAIL: DKIM-Signature header not found in forwarded message" && exit 1 )
  echo "PASS: DKIM-Signature header present"
fi

echo ""
echo "All checks passed!"
exit 0
