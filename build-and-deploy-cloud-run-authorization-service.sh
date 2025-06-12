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

OUTFILE=$(mktemp /tmp/dotnet-service-deploy.out.XXXXXX)
rand_string=$(cat /dev/urandom | LC_CTYPE=C tr -cd '[:alnum:]' | head -c 4 | tr '[:upper:]' '[:lower:]')
SA_REQUIRED_ROLES=()
example_name="server"

source ./lib/utils.sh

check_and_maybe_create_sa() {
  local ROLE ARR
  printf "Checking for service account %s...\n" "$SA_EMAIL"
  printf "Checking for service account %s...\n" "$SA_EMAIL" >>"$OUTFILE"
  echo "gcloud iam service-accounts describe \"$SA_EMAIL\" --quiet" >>"$OUTFILE"
  if gcloud iam service-accounts describe "$SA_EMAIL"  --quiet >>"$OUTFILE" 2>&1; then
    printf "That service account exists...\n"
  else
    printf "Creating service account %s ...\n" "${SERVICE_ACCOUNT}"
    printf "Creating service account %s...\n" "${SERVICE_ACCOUNT}" >>"$OUTFILE"
    echo "gcloud iam service-accounts create \"${SERVICE_ACCOUNT}\" --project=\"${CRUN_PROJECT}\" --quiet" >>"$OUTFILE"
    gcloud iam service-accounts create "${SERVICE_ACCOUNT}" --project="${CRUN_PROJECT}" --quiet >>"$OUTFILE" 2>&1

    if [[ ${#SA_REQUIRED_ROLES[@]} -ne 0 ]]; then
      printf "There can be errors if all these changes happen too quickly, so we need to sleep a bit...\n"
      sleep 12
    fi
  fi
}

# ====================================================================

check_required_commands gcloud
check_shell_variables CRUN_PROJECT CRUN_REGION SERVICE_ROOT SHEET_ID

# derived variables
SERVICE_ACCOUNT="${SERVICE_ROOT}-${rand_string}"
SA_EMAIL="${SERVICE_ACCOUNT}@${CRUN_PROJECT}.iam.gserviceaccount.com"
SERVICE="${SERVICE_ROOT}-${example_name}"

printf "Logging to %s\n" "$OUTFILE"
printf "You must share the sheet with this service account: %s\n" "$SA_EMAIL"
printf "You must share the sheet with this service account: %s\n" "$SA_EMAIL" >>"$OUTFILE"

check_and_maybe_create_sa

clean_files

printf "Deploying the service to Cloud Run\n"
printf "Deploying the service to Cloud Run\n" >>"$OUTFILE"
echo "gcloud run deploy \"${SERVICE}\" \
  --source \".\" \
  --project \"${CRUN_PROJECT}\" \
  --concurrency 5 \
  --cpu 1 \
  --memory '512Mi' \
  --min-instances 0 \
  --max-instances 1 \
  --set-env-vars SHEET_ID=\"${SHEET_ID}\" \
  --allow-unauthenticated \
  --update-build-env-vars=\"GCLOUD_BUILD=1\" \
  --region \"${CRUN_REGION}\" \
  --service-account \"${SA_EMAIL}\" \
  --timeout 380" >>$OUTFILE

gcloud run deploy "${SERVICE}" \
  --source "./" \
  --project "${CRUN_PROJECT}" \
  --concurrency 5 \
  --cpu 1 \
  --memory '512Mi' \
  --min-instances 0 \
  --max-instances 1 \
  --set-env-vars SHEET_ID="${SHEET_ID}" \
  --allow-unauthenticated \
  --update-build-env-vars="GCLOUD_BUILD=1" \
  --region "${CRUN_REGION}" \
  --service-account "${SA_EMAIL}" \
  --timeout 380
