#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
register_user() { # email password
  cv_http POST /auth/register "$(jq -nc --arg e "$1" --arg p "$2" --arg n "CV User $SUFFIX" "{email:\$e,password:\$p,name:\$n}")"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering $1 got $CV_HTTP_STATUS" $LINENO
}

EMAIL="cv_unregistered_${SUFFIX}@example.com"
# Given
cv_step Given "an email that belongs to no registered account" $LINENO
cv_prereq "using a fresh unique email $EMAIL that is never registered" $LINENO
# When
cv_step When "someone signs in with the unregistered email" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "AnyPass-${SUFFIX}" '{email:$e,password:$p}')"
# Then
cv_step Then "sign-in is refused and no token is issued" $LINENO
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 for unregistered email got $CV_HTTP_STATUS" $LINENO
[ -z "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty' 2>/dev/null)" ] || cv_fail "expected no token got $CV_HTTP_BODY" $LINENO
# Cleanup
cv_step Cleanup "nothing created" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_53446503_3"
