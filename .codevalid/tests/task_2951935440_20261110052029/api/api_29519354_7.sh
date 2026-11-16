#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="victim7_${SUFFIX}@example.com"
VICTIM_PW="Victim-${SUFFIX}-pw"
ATTACKER_PW="Attacker-${SUFFIX}-pw"

# Given
cv_step Given "customer A registered with a known password" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$VICTIM_PW" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected victim register 201 got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO

# When
cv_step When "attacker submits a registration with A's email" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$ATTACKER_PW" '{email:$e,password:$p}')"
DUP_STATUS="$CV_HTTP_STATUS"; DUP_BODY="$CV_HTTP_BODY"; DUP_HDRS="$(cat "$CV_HTTP_HEADERS_FILE")"

# Then
cv_step Then "the refusal reveals no password or stored credential data of A" $LINENO
case "$DUP_STATUS" in 4??) ;; *) cv_fail "expected refusal got $DUP_STATUS: $DUP_BODY" $LINENO ;; esac
case "$DUP_BODY$DUP_HDRS" in *"$VICTIM_PW"*) cv_fail "expected A's password not in refusal got it exposed: $DUP_BODY" $LINENO ;; esac
if echo "$DUP_BODY" | grep -Eq '\$2[aby]?\$[0-9]{2}\$'; then cv_fail "expected no bcrypt hash in refusal got $DUP_BODY" $LINENO; fi
KEYS="$(echo "$DUP_BODY" | jq -r '[paths|last|strings|ascii_downcase]|map(select(test("pass|hash|salt|token")))|join(",")' 2>/dev/null || true)"
[ -z "$KEYS" ] || cv_fail "expected no credential fields in refusal got $KEYS" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: in-memory store, no delete route" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_29519354_7"
