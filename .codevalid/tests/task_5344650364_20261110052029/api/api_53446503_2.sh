#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
register_user() { # email password
  cv_http POST /auth/register "$(jq -nc --arg e "$1" --arg p "$2" --arg n "CV User $SUFFIX" "{email:\$e,password:\$p,name:\$n}")"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering $1 got $CV_HTTP_STATUS" $LINENO
}

EMAIL="cv_wrongpw_${SUFFIX}@example.com"; PASSWORD="CvPass-${SUFFIX}"
# Given
cv_step Given "a registered customer" $LINENO
register_user "$EMAIL" "$PASSWORD"
# When
cv_step When "the customer signs in with the correct email and a wrong password" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "Wrong-${PASSWORD}" '{email:$e,password:$p}')"
# Then
cv_step Then "sign-in is refused and no token is issued" $LINENO
case "$CV_HTTP_STATUS" in 2*) cv_fail "expected sign-in refused got $CV_HTTP_STATUS" $LINENO ;; esac
[ "$CV_HTTP_STATUS" = "401" ] || [ "$CV_HTTP_STATUS" = "400" ] || cv_fail "expected 401/400 got $CV_HTTP_STATUS" $LINENO
[ -z "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty' 2>/dev/null)" ] || cv_fail "expected no token in refused sign-in got $CV_HTTP_BODY" $LINENO
# Cleanup
cv_step Cleanup "in-memory store; no delete endpoints exist" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_53446503_2"
