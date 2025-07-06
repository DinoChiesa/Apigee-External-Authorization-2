#!/bin/bash

# Copyright 2024-2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

OUTFILE=$(mktemp /tmp/apiproxy-clean.out.XXXXXX)
PROXY_NAME="ec-access-control"

source ./lib/utils.sh

delete_apiproxy() {
  local proxy_name TMPFILE ENVNAME REV NUM_DEPLOYS
  proxy_name=$1
  printf "Checking Proxy %s\n" "${proxy_name}"
  printf "Checking Proxy %s\n" "${proxy_name}" >>"$OUTFILE"
  printf "apigeecli apis get --name \"$proxy_name\" --org \"$APIGEE_PROJECT\" --token \"****\" --disable-check\n" >>"$OUTFILE"
  if apigeecli apis get --name "$proxy_name" --org "$APIGEE_PROJECT" --token "$TOKEN" --disable-check >/dev/null 2>&1; then
    TMPFILE=$(mktemp /tmp/apigee-samples.apigeecli.out.XXXXXX)
    printf "apigeecli apis listdeploy --name \"$proxy_name\" --org \"$APIGEE_PROJECT\" --token \"****\" --disable-check\n"
    printf "apigeecli apis listdeploy --name \"$proxy_name\" --org \"$APIGEE_PROJECT\" --token \"****\" --disable-check\n" >>"$OUTFILE"
    if apigeecli apis listdeploy --name "$proxy_name" --org "$APIGEE_PROJECT" --token "$TOKEN" --disable-check >"$TMPFILE" 2>&1; then
      NUM_DEPLOYS=$(jq -r '.deployments | length' "$TMPFILE")
      if [[ $NUM_DEPLOYS -ne 0 ]]; then
        echo "Undeploying ${proxy_name}"
        for ((i = 0; i < NUM_DEPLOYS; i++)); do
          ENVNAME=$(jq -r ".deployments[$i].environment" "$TMPFILE")
          REV=$(jq -r ".deployments[$i].revision" "$TMPFILE")

          printf "apigeecli apis undeploy --name \"${proxy_name}\" --env \"$ENVNAME\" --rev \"$REV\" --org \"$APIGEE_PROJECT\" --token \"****\" --safeundeploy=false --disable-check\n"
          printf "apigeecli apis undeploy --name \"${proxy_name}\" --env \"$ENVNAME\" --rev \"$REV\" --org \"$APIGEE_PROJECT\" --token \"****\" --safeundeploy=false --disable-check\n" >>"$OUTFILE"
          apigeecli apis undeploy --name "${proxy_name}" --env "$ENVNAME" --rev "$REV" --org "$APIGEE_PROJECT" --token "$TOKEN" --safeundeploy=false --disable-check
        done
      else
        printf "  There are no deployments of %s to remove.\n" "${proxy_name}"
        printf "  There are no deployments of %s to remove.\n" "${proxy_name}" >>"$OUTFILE"
      fi
    fi
    [[ -f "$TMPFILE" ]] && rm "$TMPFILE"

    echo "Deleting proxy ${proxy_name}"
    echo "Deleting proxy ${proxy_name}" >>"$OUTFILE"
    printf "apigeecli apis delete --name \"${proxy_name}\" --org \"$PROJECT\" --token \"****\" --disable-check\n" >>"$OUTFILE"
    apigeecli apis delete --name "${proxy_name}" --org "$PROJECT" --token "$TOKEN" --disable-check
  else
    printf "  The proxy %s does not exist.\n" "${proxy_name}"
    printf "  The proxy %s does not exist.\n" "${proxy_name}" >>"$OUTFILE"
  fi
}

remove_target_server() {
  local target_server_name
  target_server_name="$1"
  printf "Checking the Apigee target server %s...\n" "${target_server_name}"
  printf "Checking the Apigee target server %s...\n" "${target_server_name}" >>"$OUTFILE"
  CURL -X GET "https://apigee.googleapis.com/v1/organizations/${APIGEE_PROJECT}/environments/${APIGEE_ENV}/targetservers/${target_server_name}"
  if [[ ${CURL_RC} -eq 200 ]]; then
    printf "Deleting the Apigee target server %s...\n" "${target_server_name}"
    printf "Deleting the Apigee target server %s...\n" "${target_server_name}" >>"$OUTFILE"
    CURL -X DELETE "https://apigee.googleapis.com/v1/organizations/${APIGEE_PROJECT}/environments/${APIGEE_ENV}/targetservers/${target_server_name}"
    if [[ ${CURL_RC} -ne 200 ]]; then
      printf "Could not delete the target server: ${CURL_RC}.\n"
    fi
  else
    printf "That target server does not exist. Nothing to delete.\n"
  fi
}

# ====================================================================

check_required_commands gcloud curl jq bash
check_shell_variables APIGEE_PROJECT APIGEE_ENV APIGEE_HOST

TOKEN=$(gcloud auth print-access-token)

if [[ ! -d "$HOME/.apigeecli/bin" ]]; then
  printf "apigeecli is not installed in the default location (%s).\n" "$HOME/.apigeecli/bin" >&2
  printf "Please install it from https://github.com/apigee/apigeecli\n" >&2
  exit 1
fi
export PATH=$PATH:$HOME/.apigeecli/bin

delete_apiproxy "${PROXY_NAME}"
remove_target_server "dotnet-access-control-server"

echo " "
echo "All the Apigee artifacts should have been removed."
echo " "
