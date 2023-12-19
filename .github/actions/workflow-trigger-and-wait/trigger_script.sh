#!/usr/bin/env bash
set -e

# Arguments
OWNER="${1}"
REPO="${2}"
GITHUB_TOKEN="${3}"
WORKFLOW_FILE_NAME="${4}"  # This should be the workflow file name or ID
REF="${5}"
CLIENT_PAYLOAD="${6}"  # JSON payload for inputs

# GitHub API URL
GITHUB_API_URL="https://api.github.com"

# Function to make API calls with improved error handling
api_call() {
  path=$1
  method=$2
  data=$3

  response=$(curl --fail-with-body -L -sSL -w "%{http_code}" -X "$method" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    "${GITHUB_API_URL}/repos/${OWNER}/${REPO}/actions/$path" \
    -d "$data")

  http_code=$(tail -n1 <<<"$response")  # Extract HTTP status code
  response_body=$(sed '$ d' <<<"$response")  # Extract response body

  echo "HTTP Response Code: $http_code"
  echo "API Response: $response_body"

  if [ "$http_code" -ne 200 ] && [ "$http_code" -ne 201 ]; then
    echo >&2 "API call failed with status $http_code: $path"
    exit 1
  fi
  echo "$response_body"
}

# Trigger the workflow
echo "Attempting to trigger workflow: ${WORKFLOW_FILE_NAME}"
trigger_response=$(api_call "workflows/${WORKFLOW_FILE_NAME}/dispatches" "POST" "{\"ref\":\"${REF}\",\"inputs\":${CLIENT_PAYLOAD}}")

if [ "$(jq -r '.message' <<<"$trigger_response")" != "null" ]; then
  echo >&2 "Failed to trigger the workflow. Response message: $(jq -r '.message' <<<"$trigger_response")"
  exit 1
else
  echo "Workflow trigger appears successful."
fi

# Function to wait and check the workflow status
wait_and_check_status() {
  workflow_run_id=${1:?}

  while true; do
    sleep "$WAIT_INTERVAL"
    workflow=$(api_call "runs/$workflow_run_id" "GET" "")
    status=$(echo "$workflow" | jq -r '.status')
    conclusion=$(echo "$workflow" | jq -r '.conclusion')

    if [[ "$status" == "completed" ]]; then
      echo "Workflow completed with status: $conclusion"
      return 0
    else
      echo "Workflow still running. Current status: $status"
    fi
  done
}

# Extract the workflow run ID and URL
run_id=$(echo "$trigger_response" | jq -r '.id')
run_url="${GITHUB_SERVER_URL}/${OWNER}/${REPO}/actions/runs/${run_id}"
echo "Workflow run URL: $run_url"

# Wait for workflow to complete and check its status
wait_and_check_status "$run_id"
