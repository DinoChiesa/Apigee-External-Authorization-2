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

set -e

source ./lib/utils.sh

delete_service_sa() {
  local service project sa_email
  local short_sa="$1"
  local project="$2"
  sa_email="${short_sa}@${project}.iam.gserviceaccount.com"
  printf "Checking for service account %s...\n" "$sa_email"
  echo "gcloud iam service-accounts describe \"$sa_email\""
  if gcloud iam service-accounts describe "$sa_email" --quiet >> /dev/null 2>&1 ; then
    printf "That service account exists. Deleting it...\n"
    echo "gcloud iam service-accounts delete \"$sa_email\""
    if gcloud --quiet iam service-accounts delete "$sa_email" 2>&1; then
      printf "The service account (%s) has been deleted.\n" "${sa_email}"
    else
      printf "The service account (%s) could not be  deleted.\n" "${sa_email}"
    fi
  else
    printf "The service account (%s) does not exist.\n" "$sa_email"
  fi
}

# ====================================================================

check_shell_variables CLOUDRUN_PROJECT_ID CLOUDRUN_REGION CLOUDRUN_SERVICE_NAME CLOUDRUN_SHORT_SA
check_required_commands gcloud

printf "gcloud run services describe \"${CLOUDRUN_SERVICE_NAME}\" --project \"${CLOUDRUN_PROJECT_ID}\" --region \"${CLOUDRUN_REGION}\"\n"
if gcloud --quiet run services describe "${CLOUDRUN_SERVICE_NAME}" --project "${CLOUDRUN_PROJECT_ID}" --region "${CLOUDRUN_REGION}" >>/dev/null 2>&1; then
  printf "That service exists...\n"
  printf "Removing the service from Cloud Run\n"
  echo "gcloud run services delete  \"${CLOUDRUN_SERVICE_NAME}\" --project \"${CLOUDRUN_PROJECT_ID}\" --region \"${CLOUDRUN_REGION}\""
  if gcloud --quiet run services delete "${CLOUDRUN_SERVICE_NAME}" --project "${CLOUDRUN_PROJECT_ID}" --region "${CLOUDRUN_REGION}"; then
    printf "The service with name (%s) has been deleted.\n" "${CLOUDRUN_SERVICE_NAME}"
  else
    printf "The service with name (%s) could not be deleted.\n" "${CLOUDRUN_SERVICE_NAME}"
  fi
else
  printf "The service with name (%s) does not exist.\n" "${CLOUDRUN_SERVICE_NAME}"
fi

delete_service_sa "$CLOUDRUN_SHORT_SA" "$CLOUDRUN_PROJECT_ID"

printf "\nOK\n\n"
