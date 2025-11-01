#!/bin/sh
set -e

trap exit TERM
CODE=$(awk 'BEGIN{srand(); print int(100000 + rand() * 899999)}')
echo "Verification Code: $CODE"

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
nc -i 2 server 25 < /smtp.txt

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

cat /pop3.txt | openssl s_client \
  -CAfile /etc/letsencrypt/live/mail.contoso.com/fullchain.pem \
  -quiet -servername mail.contoso.com -connect server:995 > /output.txt

cat /output.txt

grep -E 'fhqwhgads@contoso.local' /output.txt || ( echo "'rcpt to' was not found" && exit 1 )
grep -E -i "verification code $CODE" /output.txt || ( echo "'verification code' was not found" && exit 1 )

exit 0
