#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
register_user() { # email password
  cv_http POST /auth/register "$(jq -nc --arg e "$1" --arg p "$2" --arg n "CV User $SUFFIX" "{email:\$e,password:\$p,name:\$n}")"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering $1 got $CV_HTTP_STATUS" $LINENO
}

EMAIL="cv_catalog_${SUFFIX}@example.com"; PASSWORD="CvPass-${SUFFIX}"; PNAME="CV Catalog Item $SUFFIX"
# Given
cv_step Given "a product exists in the catalog" $LINENO
register_user "$EMAIL" "$PASSWORD"
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token')
cv_http POST /products "$(jq -nc --arg n "$PNAME" '{name:$n,description:"catalog check",price:12.5}')" 201 -H "Authorization: Bearer $TOKEN"
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id')
# When
cv_step When "an anonymous visitor requests the full catalog" $LINENO
cv_http GET /products
# Then
cv_step Then "the catalog is returned and contains the product" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e --arg id "$PID" --arg n "$PNAME" '.products | any(.id==$id and .name==$n and .price==12.5)' >/dev/null || cv_fail "expected product $PID in catalog" $LINENO
# Cleanup
cv_step Cleanup "in-memory store; no delete endpoints exist" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_53446503_5"
