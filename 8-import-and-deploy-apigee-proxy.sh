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

# ====================================================================

check_shell_variables APIGEE_PROJECT_ID APIGEE_ENV APIGEE_HOST 
check_required_commands gcloud jq 

if [[ ! -d "$HOME/.apigeecli/bin" ]]; then
  printf "apigeecli is not installed in the default location (%s).\n" "$HOME/.apigeecli/bin" >&2
  printf "Please install it from https://github.com/apigee/apigeecli\n" >&2
  exit 1
fi
export PATH=$PATH:$HOME/.apigeecli/bin

TOKEN=$(gcloud auth print-access-token)

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
