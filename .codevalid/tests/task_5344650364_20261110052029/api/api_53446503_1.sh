#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
register_user() { # email password
  cv_http POST /auth/register "$(jq -nc --arg e "$1" --arg p "$2" --arg n "CV User $SUFFIX" "{email:\$e,password:\$p,name:\$n}")"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering $1 got $CV_HTTP_STATUS" $LINENO
}

EMAIL="cv_signin_${SUFFIX}@example.com"; PASSWORD="CvPass-${SUFFIX}"
# Given
cv_step Given "a customer registered with email and password" $LINENO
register_user "$EMAIL" "$PASSWORD"
# When
cv_step When "the customer signs in with the registered email and password" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
LOGIN_STATUS=$CV_HTTP_STATUS; LOGIN_BODY=$CV_HTTP_BODY
# Then
cv_step Then "sign-in succeeds and the token is accepted on a signed-in-only request" $LINENO
[ "$LOGIN_STATUS" = "200" ] || cv_fail "expected 200 from login got $LOGIN_STATUS" $LINENO
TOKEN=$(printf '%s' "$LOGIN_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected token in login response got $LOGIN_BODY" $LINENO
[ "$(printf '%s' "$LOGIN_BODY" | jq -r '.user.email')" = "$EMAIL" ] || cv_fail "expected user.email $EMAIL in login response" $LINENO
printf '%s' "$LOGIN_BODY" | jq -e '.user | has("passwordHash") or has("password") | not' >/dev/null || cv_fail "expected no password data in login response" $LINENO
cv_http POST /products "$(jq -nc --arg n "CV signed-in check $SUFFIX" '{name:$n,price:1}')" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected signed-in token to be accepted (201) got $CV_HTTP_STATUS" $LINENO
# Cleanup
cv_step Cleanup "in-memory store; no delete endpoints exist, unique data left in place" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_53446503_1"
