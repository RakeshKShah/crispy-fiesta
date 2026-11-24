#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
PASSWORD="Pw-${SUFFIX}-ok"

# Given
cv_step Given "a registration payload with a password but no email" $LINENO
BODY="$(jq -nc --arg p "$PASSWORD" '{password:$p}')"
cv_prereq "payload built: $BODY" $LINENO

# When
cv_step When "the customer submits the registration without email" $LINENO
cv_http POST /auth/register "$BODY"
REG_STATUS="$CV_HTTP_STATUS"; REG_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "the registration is refused and no account or token is issued" $LINENO
case "$REG_STATUS" in 4??) ;; *) cv_fail "expected 4xx refusal got $REG_STATUS: $REG_BODY" $LINENO ;; esac
[ -z "$(echo "$REG_BODY" | jq -r '.token // empty' 2>/dev/null)" ] || cv_fail "expected no token got $REG_BODY" $LINENO
[ -z "$(echo "$REG_BODY" | jq -r '.user.id // empty' 2>/dev/null)" ] || cv_fail "expected no user created got $REG_BODY" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: no account was created" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_29519354_2"
