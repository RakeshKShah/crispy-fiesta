#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cust3_${SUFFIX}@example.com"
PASSWORD="Pw-${SUFFIX}-ok"

# Given
cv_step Given "an unregistered email address and a payload without password" $LINENO
BODY="$(jq -nc --arg e "$EMAIL" '{email:$e}')"
cv_prereq "payload built: $BODY" $LINENO

# When
cv_step When "the customer submits the registration without password" $LINENO
cv_http POST /auth/register "$BODY"
REG_STATUS="$CV_HTTP_STATUS"; REG_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "registration refused, no account, and the email can still be registered" $LINENO
case "$REG_STATUS" in 4??) ;; *) cv_fail "expected 4xx refusal got $REG_STATUS: $REG_BODY" $LINENO ;; esac
[ -z "$(echo "$REG_BODY" | jq -r '.token // empty' 2>/dev/null)" ] || cv_fail "expected no token got $REG_BODY" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected email still available (201) got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: in-memory store, no delete route" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_29519354_3"
