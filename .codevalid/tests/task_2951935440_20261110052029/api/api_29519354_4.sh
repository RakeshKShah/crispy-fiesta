#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cust4_${SUFFIX}@example.com"
PASSWORD="Pw-${SUFFIX}-orig"
PASSWORD2="Pw-${SUFFIX}-second"

# Given
cv_step Given "an account already registered with the email" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" --arg n "Original $SUFFIX" '{email:$e,password:$p,name:$n}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected setup register 201 got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
ORIG_ID="$(echo "$CV_HTTP_BODY" | jq -r '.user.id')"
ORIG_NAME="$(echo "$CV_HTTP_BODY" | jq -r '.user.name')"

# When
cv_step When "a second registration with the same email is submitted" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD2" --arg n "Second $SUFFIX" '{email:$e,password:$p,name:$n}')"
DUP_STATUS="$CV_HTTP_STATUS"; DUP_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "refused, no second account, existing account unchanged" $LINENO
case "$DUP_STATUS" in 4??) ;; *) cv_fail "expected 4xx refusal got $DUP_STATUS: $DUP_BODY" $LINENO ;; esac
[ -z "$(echo "$DUP_BODY" | jq -r '.user.id // empty' 2>/dev/null)" ] || cv_fail "expected no new user got $DUP_BODY" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected original password login 200 got $CV_HTTP_STATUS" $LINENO
[ "$(echo "$CV_HTTP_BODY" | jq -r '.user.id')" = "$ORIG_ID" ] || cv_fail "expected same user id $ORIG_ID got $CV_HTTP_BODY" $LINENO
[ "$(echo "$CV_HTTP_BODY" | jq -r '.user.name')" = "$ORIG_NAME" ] || cv_fail "expected name unchanged $ORIG_NAME got $CV_HTTP_BODY" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD2" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected second password login 401 (no second account) got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: in-memory store, no delete route" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_29519354_4"
