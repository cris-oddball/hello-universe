# Re-creating the enhanced trigger_script.sh after code execution state reset

enhanced_script = """
#!/usr/bin/env bash
set -e

# Arguments
OWNER="${1}"
REPO="${2}"
GITHUB_TOKEN="${3}"
WORKFLOW_FILE_NAME="${4}"
REF="${5}"
CLIENT_PAYLOAD="${6}"
WAIT_INTERVAL=${7:-10} # Default wait interval is 10 seconds

# GitHub API URLs
GITHUB_API_URL="https://api.github.com"
GITHUB_SERVER_URL="https://github.com"

# Function to make API calls
api_call() {
  path=$1
  method=$2
  data=$3

  response=$(curl -sSL -X "$method" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H 'Accept: application/vnd.github.v3+json' \
    -H 'Content-Type: application/json' \
    "${GITHUB_API_URL}/repos/${OWNER}/${REPO}/actions/$path" \
    -d "$data")

  echo "API Response: $response"  # Echo the full JSON response

  if [ $? -ne 0 ]; then
    echo >&2 "API call failed: $path"
    exit 1
  fi
  echo "$response"
}

# Trigger the workflow
echo "Triggering workflow: ${WORKFLOW_FILE_NAME}"
trigger_response=$(api_call "workflows/${WORKFLOW_FILE_NAME}/dispatches" "POST" "{\"ref\":\"${REF}\",\"inputs\":${CLIENT_PAYLOAD}}")
echo "Workflow triggered successfully."

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
"""

enhanced_script

