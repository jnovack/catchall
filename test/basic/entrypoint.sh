#!/bin/sh
set -e

trap exit TERM
CODE=$(awk 'BEGIN{srand(); print int(100000 + rand() * 899999)}')
echo "Verification Code: $CODE"

# ensure shared code file starts clean
rm -f /shared/code.txt

cat <<EOF > /smtp.txt
EHLO fabrikam.home
mail from:<me@fabrikam.home>
rcpt to:fhqwhgads@contoso.local
data
Subject: Test Email

Body of the email.
Verification Code $CODE

.
quit
EOF

while :; do
  nc -z server 25 && break
  echo "waiting for smtp..."
  sleep 2 & wait $!
done

cat /smtp.txt
nc -i 1 server 25 < /smtp.txt

# ---- Verify STARTTLS ----
echo "Checking for STARTTLS in EHLO response..."
printf "EHLO test\r\nQUIT\r\n" | nc -i 1 server 25 | grep -qi "STARTTLS" \
  || ( echo "FAIL: STARTTLS not advertised in EHLO" && exit 1 )
echo "PASS: STARTTLS advertised"

echo "Verifying STARTTLS handshake..."
openssl s_client -starttls smtp \
  -CAfile /etc/letsencrypt/live/mail.contoso.com/fullchain.pem \
  -servername mail.contoso.com -connect server:25 \
  </dev/null 2>&1 \
  | grep -q "Verify return code: 0" \
  || ( echo "FAIL: STARTTLS handshake failed" && exit 1 )
echo "PASS: STARTTLS handshake succeeded"

cat <<EOF > /pop3.txt
USER catchall
PASS hunter2
LIST
RETR 1
DELE 1
QUIT
EOF

while :; do
  nc -z server 995 && break
  echo "waiting for pop3..."
  sleep 2 & wait $!
done

echo "Checking imap for messgaes, should be 1"
curl -u catchall:hunter2 --silent --insecure --url -k "imaps://server/INBOX"  -X 'STATUS INBOX (MESSAGES)'

cat /pop3.txt | openssl s_client \
  -CAfile /etc/letsencrypt/live/mail.contoso.com/fullchain.pem \
  -quiet -servername mail.contoso.com -connect server:995 > /output.txt

echo "Checking imap for messgaes, should be 0"
curl -u catchall:hunter2 --silent --insecure --url -k "imaps://server/INBOX"  -X 'STATUS INBOX (MESSAGES)'

echo "POP3 output"
cat /output.txt

grep -E 'fhqwhgads@contoso.local' /output.txt || ( echo "'rcpt to' was not found" && exit 1 )
grep -E -i "verification code $CODE" /output.txt || ( echo "'verification code' was not found" && exit 1 )
grep -Fx "$CODE" /shared/code.txt || ( echo "Sieve did not capture the expected code" && exit 1 )

exit 0
