#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
UNKNOWN_ID="00000000-0000-4000-8000-$(printf '%012d' "$((SUFFIX % 1000000000000))")"

# Given
cv_step Given "an identifier that matches no product in the catalog" $LINENO
cv_http GET /products 200
echo "$CV_HTTP_BODY" | jq -e --arg id "$UNKNOWN_ID" 'any(.products[]; .id == $id) | not' >/dev/null || cv_fail "expected $UNKNOWN_ID to be unused got it in catalog" $LINENO

# When
cv_step When "a visitor opens a product with the unknown identifier" $LINENO
cv_http GET "/products/$UNKNOWN_ID"

# Then
cv_step Then "no product is returned and the response shows not found" $LINENO
[ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected 404 for unknown product got $CV_HTTP_STATUS" $LINENO
echo "$CV_HTTP_BODY" | jq -e '.product == null' >/dev/null || cv_fail "expected no product data got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "nothing was created" $LINENO
echo "nothing to remove"

echo "CODEVALID_TEST_ASSERTION_OK:api_43736470_4"
