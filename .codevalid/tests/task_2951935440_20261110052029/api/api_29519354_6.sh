#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="victim6_${SUFFIX}@example.com"
VICTIM_PW="Victim-${SUFFIX}-pw"
ATTACKER_PW="Attacker-${SUFFIX}-pw"

# Given
cv_step Given "victim A registered with their own password" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$VICTIM_PW" --arg n "Victim $SUFFIX" '{email:$e,password:$p,name:$n}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected victim register 201 got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
VICTIM_ID="$(echo "$CV_HTTP_BODY" | jq -r '.user.id')"
VICTIM_NAME="$(echo "$CV_HTTP_BODY" | jq -r '.user.name')"

# When
cv_step When "attacker registers with A's email and a new password" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$ATTACKER_PW" --arg n "Attacker" '{email:$e,password:$p,name:$n}')"
ATK_STATUS="$CV_HTTP_STATUS"; ATK_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "refused; attacker gets no token; A's password and account unchanged" $LINENO
case "$ATK_STATUS" in 4??) ;; *) cv_fail "expected refusal got $ATK_STATUS: $ATK_BODY" $LINENO ;; esac
[ -z "$(echo "$ATK_BODY" | jq -r '.token // empty' 2>/dev/null)" ] || cv_fail "expected no token issued to attacker got $ATK_BODY" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$ATTACKER_PW" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected attacker password login 401 got $CV_HTTP_STATUS (account taken over)" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$VICTIM_PW" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected victim password login 200 got $CV_HTTP_STATUS" $LINENO
[ "$(echo "$CV_HTTP_BODY" | jq -r '.user.id')" = "$VICTIM_ID" ] || cv_fail "expected victim id $VICTIM_ID got $CV_HTTP_BODY" $LINENO
[ "$(echo "$CV_HTTP_BODY" | jq -r '.user.name')" = "$VICTIM_NAME" ] || cv_fail "expected victim name unchanged got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: in-memory store, no delete route" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_29519354_6"
