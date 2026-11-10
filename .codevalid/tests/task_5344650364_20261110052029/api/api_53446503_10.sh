#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cv_pwpriv_${SUFFIX}@example.com"; PASSWORD="CvSecret-${SUFFIX}"
password_leak() { # body -> prints what leaked, empty if nothing
  if printf '%s' "$1" | grep -qF -- "$PASSWORD"; then echo "plaintext password"; return; fi
  if printf '%s' "$1" | grep -qE '\$2[aby]\$[0-9]{2}\$'; then echo "password hash"; return; fi
  if printf '%s' "$1" | jq -e '[.. | objects | keys[] | ascii_downcase | select(test("password"))] | length > 0' >/dev/null 2>&1; then
    echo "password field"; return
  fi
}

# Given
cv_step Given "a registered customer who has added a product to the catalog" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering got $CV_HTTP_STATUS" $LINENO
REG_TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$REG_TOKEN" ] || cv_fail "expected token from register" $LINENO
cv_http POST /products "$(jq -nc --arg n "CV pwpriv $SUFFIX" '{name:$n,price:3}')" -H "Authorization: Bearer $REG_TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 creating product got $CV_HTTP_STATUS" $LINENO
PRODUCT_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PRODUCT_ID" ] || cv_fail "expected product id" $LINENO

# When
cv_step When "the customer signs in and the catalog and the product are requested" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
LOGIN_STATUS=$CV_HTTP_STATUS; LOGIN_BODY=$CV_HTTP_BODY
cv_http GET /products
LIST_STATUS=$CV_HTTP_STATUS; LIST_BODY=$CV_HTTP_BODY
cv_http GET "/products/$PRODUCT_ID"
ONE_STATUS=$CV_HTTP_STATUS; ONE_BODY=$CV_HTTP_BODY

# Then
cv_step Then "no response contains the password, its hash or a password field" $LINENO
[ "$LOGIN_STATUS" = "200" ] || cv_fail "expected 200 from login got $LOGIN_STATUS" $LINENO
[ "$LIST_STATUS" = "200" ] || cv_fail "expected 200 listing products got $LIST_STATUS" $LINENO
[ "$ONE_STATUS" = "200" ] || cv_fail "expected 200 reading product got $ONE_STATUS" $LINENO
LEAK=$(password_leak "$LOGIN_BODY"); [ -z "$LEAK" ] || cv_fail "expected no password data in sign-in response got $LEAK" $LINENO
LEAK=$(password_leak "$LIST_BODY"); [ -z "$LEAK" ] || cv_fail "expected no password data in catalog response got $LEAK" $LINENO
LEAK=$(password_leak "$ONE_BODY"); [ -z "$LEAK" ] || cv_fail "expected no password data in product response got $LEAK" $LINENO

# Cleanup
cv_step Cleanup "in-memory store; no delete endpoints exist, unique data left in place" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_53446503_10"
