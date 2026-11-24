#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cv_badpw_${SUFFIX}@example.com"
SECRET_PART="Zq7Stored${SUFFIX}"
PASSWORD="Pw-${SECRET_PART}"
WRONG="Wrong-pass-${SUFFIX}"

# Given
cv_step Given "a registered customer with a known stored password" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering got $CV_HTTP_STATUS" $LINENO

# When
cv_step When "someone signs in with the registered email and a wrong password" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$WRONG" '{email:$e,password:$p}')"
STATUS=$CV_HTTP_STATUS; BODY=$CV_HTTP_BODY; HEADERS=$(cat "$CV_HTTP_HEADERS_FILE" 2>/dev/null || true)

# Then
cv_step Then "sign-in is refused and the refusal reveals nothing of the stored password" $LINENO
case "$STATUS" in 2*) cv_fail "expected sign-in with wrong password to be refused got $STATUS" $LINENO ;; esac
ALL="$HEADERS
$BODY"
if printf '%s' "$ALL" | grep -qF -- "$PASSWORD"; then cv_fail "expected refusal not to contain the stored password" $LINENO; fi
if printf '%s' "$ALL" | grep -qF -- "$SECRET_PART"; then cv_fail "expected refusal not to contain part of the stored password" $LINENO; fi
if printf '%s' "$ALL" | grep -qE '\$2[aby]\$[0-9]{2}\$'; then cv_fail "expected refusal not to contain the password hash" $LINENO; fi
if printf '%s' "$BODY" | jq -e '[.. | objects | keys[] | ascii_downcase | select(test("password|hash"))] | length > 0' >/dev/null 2>&1; then
  cv_fail "expected no password/hash field in refusal got $BODY" $LINENO
fi
if printf '%s' "$BODY" | jq -e '.token? // empty' >/dev/null 2>&1; then cv_fail "expected no token in refusal got $BODY" $LINENO; fi

# Cleanup
cv_step Cleanup "in-memory store; no delete endpoints exist, unique data left in place" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_53446503_11"
