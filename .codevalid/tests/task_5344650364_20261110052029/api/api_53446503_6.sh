#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
register_user() { # email password
  cv_http POST /auth/register "$(jq -nc --arg e "$1" --arg p "$2" --arg n "CV User $SUFFIX" "{email:\$e,password:\$p,name:\$n}")"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering $1 got $CV_HTTP_STATUS" $LINENO
}

EMAIL="cv_single_${SUFFIX}@example.com"; PASSWORD="CvPass-${SUFFIX}"; PNAME="CV Single Item $SUFFIX"
# Given
cv_step Given "a product exists in the catalog" $LINENO
register_user "$EMAIL" "$PASSWORD"
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token')
cv_http POST /products "$(jq -nc --arg n "$PNAME" '{name:$n,description:"single check",price:7}')" 201 -H "Authorization: Bearer $TOKEN"
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id')
# When
cv_step When "an anonymous visitor opens the product by id" $LINENO
cv_http GET "/products/$PID"
# Then
cv_step Then "the product's details are returned" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e --arg id "$PID" --arg n "$PNAME" '.product.id==$id and .product.name==$n and .product.description=="single check" and .product.price==7' >/dev/null || cv_fail "expected product $PID details got $CV_HTTP_BODY" $LINENO
# Cleanup
cv_step Cleanup "in-memory store; no delete endpoints exist" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_53446503_6"
