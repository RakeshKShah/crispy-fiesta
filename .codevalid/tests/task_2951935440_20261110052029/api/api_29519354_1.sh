#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cust1_${SUFFIX}@example.com"
PASSWORD="Pw-${SUFFIX}-ok"

# Given
cv_step Given "a new email address that has not been registered and a password" $LINENO
cv_prereq "email $EMAIL is not registered yet (login refused)" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected unregistered email login 401 got $CV_HTTP_STATUS" $LINENO

# When
cv_step When "the customer registers with email and password" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
REG_STATUS="$CV_HTTP_STATUS"; REG_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "an account exists for the email and can be logged into" $LINENO
[ "$REG_STATUS" = "201" ] || cv_fail "expected register 201 got $REG_STATUS: $REG_BODY" $LINENO
USER_ID="$(echo "$REG_BODY" | jq -r '.user.id // empty')"
[ -n "$USER_ID" ] || cv_fail "expected user.id in register response got $REG_BODY" $LINENO
[ "$(echo "$REG_BODY" | jq -r '.user.email')" = "$EMAIL" ] || cv_fail "expected user.email $EMAIL got $REG_BODY" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected login 200 for new account got $CV_HTTP_STATUS" $LINENO
[ "$(echo "$CV_HTTP_BODY" | jq -r '.user.id')" = "$USER_ID" ] || cv_fail "expected login user.id $USER_ID got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: users live in the in-memory store and the app has no delete route" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_29519354_1"
