#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cust5_${SUFFIX}@example.com"
PASSWORD="Secret-${SUFFIX}-pw"

# Given
cv_step Given "a new customer email and a distinctive password" $LINENO
BODY="$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
cv_prereq "payload prepared for $EMAIL" $LINENO

# When
cv_step When "the customer registers" $LINENO
cv_http POST /auth/register "$BODY"
REG_STATUS="$CV_HTTP_STATUS"; REG_BODY="$CV_HTTP_BODY"; REG_HDRS="$(cat "$CV_HTTP_HEADERS_FILE")"

# Then
cv_step Then "the response contains no password in any form" $LINENO
[ "$REG_STATUS" = "201" ] || cv_fail "expected register 201 got $REG_STATUS: $REG_BODY" $LINENO
case "$REG_BODY$REG_HDRS" in *"$PASSWORD"*) cv_fail "expected no plaintext password in response got it exposed: $REG_BODY" $LINENO ;; esac
B64="$(printf '%s' "$PASSWORD" | base64 | tr -d '=\n')"
case "$REG_BODY" in *"$B64"*) cv_fail "expected no base64 password in response got it exposed" $LINENO ;; esac
if echo "$REG_BODY" | grep -Eq '\$2[aby]?\$[0-9]{2}\$'; then cv_fail "expected no bcrypt hash in response got $REG_BODY" $LINENO; fi
KEYS="$(echo "$REG_BODY" | jq -r '[paths|last|strings|ascii_downcase]|map(select(test("pass|hash|salt")))|join(",")')"
[ -z "$KEYS" ] || cv_fail "expected no password/hash fields got $KEYS" $LINENO
TOKEN="$(echo "$REG_BODY" | jq -r '.token // empty')"
if [ -n "$TOKEN" ]; then
  PAYLOAD="$(echo "$TOKEN" | cut -d. -f2 | tr '_-' '/+')"
  while [ $(( ${#PAYLOAD} % 4 )) -ne 0 ]; do PAYLOAD="${PAYLOAD}="; done
  DEC="$(echo "$PAYLOAD" | base64 -d 2>/dev/null || true)"
  case "$DEC" in *"$PASSWORD"*|*passwordHash*|*'$2a$'*|*'$2b$'*) cv_fail "expected token payload without password data got $DEC" $LINENO ;; esac
fi

# Cleanup
cv_step Cleanup "nothing to remove: in-memory store, no delete route" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_29519354_5"
