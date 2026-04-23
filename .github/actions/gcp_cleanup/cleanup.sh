#!/bin/bash
set -uo pipefail

MAX_RETRIES=5
RETRY_DELAY=10

if [[ -n "${PR_ID:-}" ]]; then
  SEARCH_QUERY="displayName:ghcip${PR_ID}*"
  echo "Cleaning up resources for PR #${PR_ID} (prefix: ghcip${PR_ID})"
else
  SEARCH_QUERY="displayName:ghcitt*"
  echo "Cleaning up release CI resources (prefix: ghcitt)"
fi

get_api_prefix() {
  local service="$1"
  case "$service" in
    "compute.googleapis.com")          echo "https://compute.googleapis.com/compute/v1" ;;
    "iam.googleapis.com")              echo "https://iam.googleapis.com/v1" ;;
    "pubsub.googleapis.com")           echo "https://pubsub.googleapis.com/v1" ;;
    "secretmanager.googleapis.com")    echo "https://secretmanager.googleapis.com/v1" ;;
    "cloudfunctions.googleapis.com")   echo "https://cloudfunctions.googleapis.com/v2" ;;
    "networksecurity.googleapis.com")  echo "https://networksecurity.googleapis.com/v1" ;;
    "vpcaccess.googleapis.com")        echo "https://vpcaccess.googleapis.com/v1" ;;
    "logging.googleapis.com")          echo "https://logging.googleapis.com/v2" ;;
    *)                                 echo ""; return 1 ;;
  esac
}

delete_resource() {
  local full_name="$1"
  local asset_type="$2"
  local display_name="$3"
  local service path api_prefix url output

  service=$(echo "$full_name" | sed 's|//\([^/]*\)/.*|\1|')
  path=$(echo "$full_name" | sed 's|//[^/]*/||')

  # Service account keys are auto-deleted with their parent service account
  if [[ "$asset_type" == "iam.googleapis.com/ServiceAccountKey" ]]; then
    echo "    Skipped (auto-deleted with service account)"
    return 0
  fi

  # Storage buckets need special handling: empty contents then delete
  if [[ "$asset_type" == "storage.googleapis.com/Bucket" ]]; then
    local bucket_name="${path##*/}"
    output=$(gcloud storage rm -r "gs://${bucket_name}" 2>&1) || {
      handle_delete_error "$output" && return 0
      echo "    $output"; return 1
    }
    return 0
  fi

  api_prefix=$(get_api_prefix "$service")
  if [[ -z "$api_prefix" ]]; then
    echo "  WARNING: Unknown service '${service}' for resource '${display_name}'"
    echo "           Full name: ${full_name}"
    echo "           Manual cleanup may be required."
    return 1
  fi

  url="${api_prefix}/${path}"

  output=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    "$url") || {
    echo "    curl failed for ${url}"
    return 1
  }

  case "$output" in
    200|204)
      return 0
      ;;
    404)
      echo "    Already deleted (not found)"
      return 0
      ;;
    *)
      local body
      body=$(curl -s -X DELETE \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        "$url")
      echo "    HTTP ${output}: $(echo "$body" | jq -r '.error.message // .error.status // "unknown error"' 2>/dev/null || echo "$body")"
      return 1
      ;;
  esac
}

handle_delete_error() {
  local output="$1"
  if echo "$output" | grep -qi "not found\|NOT_FOUND\|notFound"; then
    echo "    Already deleted (not found)"
    return 0
  fi
  return 1
}

echo "Querying Cloud Asset Inventory..."
RESOURCES=$(gcloud asset search-all-resources \
  --scope="projects/${PROJECT_ID}" \
  --query="${SEARCH_QUERY}" \
  --format="json(name,assetType,displayName,location)" \
  2>/dev/null || echo "[]")

RESOURCE_COUNT=$(echo "$RESOURCES" | jq 'length')
echo "Found ${RESOURCE_COUNT} resources to clean up."

if [[ "$RESOURCE_COUNT" -eq 0 ]]; then
  echo "No orphaned resources found. Exiting."
  exit 0
fi

echo "Resources discovered:"
echo "$RESOURCES" | jq -r '.[] | "  - \(.assetType): \(.displayName) (\(.location))"'

ACCESS_TOKEN=$(gcloud auth print-access-token)

ROUND=0
REMAINING_RESOURCES="$RESOURCES"

while [[ "$ROUND" -lt "$MAX_RETRIES" ]]; do
  ROUND=$((ROUND + 1))
  CURRENT_COUNT=$(echo "$REMAINING_RESOURCES" | jq 'length')

  if [[ "$CURRENT_COUNT" -eq 0 ]]; then
    echo "All resources cleaned up successfully."
    break
  fi

  echo ""
  echo "=== Round ${ROUND}/${MAX_RETRIES} (${CURRENT_COUNT} resources remaining) ==="

  FAILED_RESOURCES="[]"

  for i in $(seq 0 $((CURRENT_COUNT - 1))); do
    ENTRY=$(echo "$REMAINING_RESOURCES" | jq -c ".[$i]")
    ASSET_TYPE=$(echo "$ENTRY" | jq -r '.assetType')
    FULL_NAME=$(echo "$ENTRY" | jq -r '.name')
    DISPLAY_NAME=$(echo "$ENTRY" | jq -r '.displayName')

    echo "  Deleting ${ASSET_TYPE}: ${DISPLAY_NAME}..."

    if delete_resource "$FULL_NAME" "$ASSET_TYPE" "$DISPLAY_NAME"; then
      echo "    OK"
    else
      echo "    FAILED (will retry)"
      FAILED_RESOURCES=$(echo "$FAILED_RESOURCES" | jq --argjson entry "$ENTRY" '. + [$entry]')
    fi
  done

  REMAINING_RESOURCES="$FAILED_RESOURCES"

  REMAINING_COUNT=$(echo "$REMAINING_RESOURCES" | jq 'length')
  if [[ "$REMAINING_COUNT" -gt 0 && "$ROUND" -lt "$MAX_RETRIES" ]]; then
    echo "Waiting ${RETRY_DELAY}s before next round..."
    sleep "$RETRY_DELAY"
  fi
done

echo ""
echo "=== Cleanup Summary ==="
echo "Total resources discovered: ${RESOURCE_COUNT}"
FINAL_REMAINING=$(echo "$REMAINING_RESOURCES" | jq 'length')
DELETED=$((RESOURCE_COUNT - FINAL_REMAINING))
echo "Successfully deleted: ${DELETED}"
echo "Failed to delete: ${FINAL_REMAINING}"

if [[ "$FINAL_REMAINING" -gt 0 ]]; then
  echo ""
  echo "Resources that could not be deleted:"
  echo "$REMAINING_RESOURCES" | jq -r '.[] | "  - \(.assetType): \(.displayName)"'
  echo ""
  echo "WARNING: Manual cleanup required for the above resources."
  exit 1
fi
