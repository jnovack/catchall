#!/bin/sh
set -e

trap exit TERM
TOKEN="GLOBAL-SIEVE-$(date +%s)"
echo "Probe token: $TOKEN"

# ---- Wait for server SMTP ----
while :; do
  nc -z server 25 && break
  echo "waiting for smtp..."
  sleep 2 & wait $!
done

# ---- Send probe email ----
cat <<EOF > /smtp.txt
EHLO fabrikam.home
mail from:<me@fabrikam.home>
rcpt to:fhqwhgads@contoso.local
data
Subject: $TOKEN
From: Test Sender <me@fabrikam.home>
To: fhqwhgads@contoso.local

Body from global sieve test.

.
quit
EOF

echo "Sending probe email..."
nc -i 1 server 25 < /smtp.txt

# ---- Verify local Dovecot copy still works with GLOBAL_SIEVE enabled ----
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

cat /pop3.txt | openssl s_client \
  -CAfile /etc/letsencrypt/live/mail.contoso.com/fullchain.pem \
  -quiet -servername mail.contoso.com -connect server:995 > /pop3-output.txt

grep -F "$TOKEN" /pop3-output.txt \
  || ( echo "FAIL: Probe message subject not found in POP3 output" && exit 1 )
echo "PASS: Mail delivery works with GLOBAL_SIEVE enabled"

exit 0
