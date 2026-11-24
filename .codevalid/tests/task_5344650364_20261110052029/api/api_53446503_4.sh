#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
register_user() { # email password
  cv_http POST /auth/register "$(jq -nc --arg e "$1" --arg p "$2" --arg n "CV User $SUFFIX" "{email:\$e,password:\$p,name:\$n}")"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering $1 got $CV_HTTP_STATUS" $LINENO
}

EMAIL="cv_missing_${SUFFIX}@example.com"; PASSWORD="CvPass-${SUFFIX}"
# Given
cv_step Given "a registered customer" $LINENO
register_user "$EMAIL" "$PASSWORD"
# When
cv_step When "sign-in requests are sent with an empty password and with an empty email" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" '{email:$e,password:""}')"
S1=$CV_HTTP_STATUS; B1=$CV_HTTP_BODY
cv_http POST /auth/login "$(jq -nc --arg p "$PASSWORD" '{email:"",password:$p}')"
S2=$CV_HTTP_STATUS; B2=$CV_HTTP_BODY
# Then
cv_step Then "both requests are refused with no token" $LINENO
case "$S1" in 4*) ;; *) cv_fail "expected 4xx for empty password got $S1" $LINENO ;; esac
case "$S2" in 4*) ;; *) cv_fail "expected 4xx for empty email got $S2" $LINENO ;; esac
[ -z "$(printf '%s' "$B1" | jq -r '.token // empty' 2>/dev/null)" ] || cv_fail "expected no token for empty password got $B1" $LINENO
[ -z "$(printf '%s' "$B2" | jq -r '.token // empty' 2>/dev/null)" ] || cv_fail "expected no token for empty email got $B2" $LINENO
# Cleanup
cv_step Cleanup "in-memory store; no delete endpoints exist" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_53446503_4"
