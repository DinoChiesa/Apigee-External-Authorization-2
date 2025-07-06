#!/bin/bash
# -*- mode:shell-script; coding:utf-8; -*-

# Copyright © 2024,2025 Google LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

PROXY_NAME="ec-access-control"

source ./lib/utils.sh

import_and_deploy_apiproxy() {
  local proxy_name rev
  proxy_name=$1
  rev=$(apigeecli apis create bundle -f "./apiproxy" -n "$proxy_name" --org "$APIGEE_PROJECT_ID" --token "$TOKEN" --disable-check | jq ."revision" -r)
  apigeecli apis deploy --wait --name "$proxy_name" --ovr --rev "$rev" --org "$APIGEE_PROJECT_ID" --env "$APIGEE_ENV" --token "$TOKEN" --disable-check
}

create_target_server() {
  local target_server_name service_host_name
  target_server_name="$1"
  service_host_name="$2"
  printf "Checking the Apigee target server %s...\n" "${target_server_name}"
  CURL -X GET "https://apigee.googleapis.com/v1/organizations/${APIGEE_PROJECT_ID}/environments/${APIGEE_ENV}/targetservers/${target_server_name}"
  if [[ ${CURL_RC} -ne 200 ]]; then
    printf "That target server does not exist.\n"
    printf "Creating the Apigee target server %s...\n" "${target_server_name}"
    CURL -X POST "https://apigee.googleapis.com/v1/organizations/${APIGEE_PROJECT_ID}/environments/${APIGEE_ENV}/targetservers" \
      -H 'Content-Type: application/json; charset=utf-8' \
      -d '{
  "name": "'${target_server_name}'",
  "description": "Example Access Control GRPC External Callout",
  "host": "'${service_host_name}'",
  "port": 443,
  "isEnabled": true,
  "sSLInfo": {
    "enabled": true
  },
  "protocol": "GRPC"
}'
    cat ${CURL_OUT}
  else
    printf "The required Apigee target server exists.\n"
  fi
}

set_service_hostname() {
  local service project service_url
  service="$1"
  project="$2"
  printf "Checking for the cloud run service %s...\n" "$service"
  echo "gcloud run services describe \"${SERVICE}\" --project \"$project\""
  if gcloud run services describe "${service}" --project "$project" 2>&1; then
    printf "That service exists...\n"
    service_url=$(gcloud run services describe "${service}" --project "$project" --format='value(status.url)')
    SERVICE_HOSTNAME=${service_url#https://}
    echo "service hostname: ${SERVICE_HOSTNAME}"
  else
    printf "The required service does not exist.\n"
    printf "Please deploy it before re-running this script.\n"
    exit 1
  fi
}

# ====================================================================

check_shell_variables APIGEE_PROJECT_ID APIGEE_ENV APIGEE_HOST CLOUDRUN_SERVICE_NAME CLOUDRUN_PROJECT_ID
check_required_commands gcloud curl jq bash


# AI! Check to see that the directory 
export PATH=$PATH:$HOME/.apigeecli/bin

TOKEN=$(gcloud auth print-access-token)

set_service_hostname "$CLOUDRUN_SERVICE_NAME" "$CLOUDRUN_PROJECT_ID"
create_target_server "example-access-control-server" "$SERVICE_HOSTNAME"
import_and_deploy_apiproxy "$PROXY_NAME"

echo "-----------------------------"
echo " "
echo "To call the API manually, use the following:"
echo " "
echo "curl -i -X GET https://${APIGEE_HOST}/${PROXY_NAME}/t1 -H \"Access-Control: person@example-company.com\""
echo "curl -i -X GET https://${APIGEE_HOST}/${PROXY_NAME}/t2 -H \"Access-Control: person@example-company.com\""
echo "curl -i -X GET https://${APIGEE_HOST}/${PROXY_NAME}/t3 -H \"Access-Control: person@partner1.org\""
echo "curl -i -X GET https://${APIGEE_HOST}/${PROXY_NAME}/t3 -H \"Access-Control: person@example-company.com\""
echo "curl -i -X GET https://${APIGEE_HOST}/${PROXY_NAME}/t3 -H \"Access-Control: partner2@gmail.com\""
echo " "
