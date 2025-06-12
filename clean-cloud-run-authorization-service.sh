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

OUTFILE=$(mktemp /tmp/dotnet-service-teardown.out.XXXXXX)
example_name="server"

source ./lib/utils.sh

check_and_maybe_delete_sa() {
  local ROLE ARR
  printf "Checking for service account %s...\n" "$SA_EMAIL"
  printf "Checking for service account %s...\n" "$SA_EMAIL" >>"$OUTFILE"
  echo "gcloud iam service-accounts describe \"$SA_EMAIL\" --quiet" >>"$OUTFILE"
  if gcloud iam service-accounts describe "$SA_EMAIL" --quiet >>"$OUTFILE" 2>&1; then
    printf "That service account exists. Deleting it...\n"
    echo "gcloud --quiet iam service-accounts delete \"$SA_EMAIL\"" >>"$OUTFILE"
    gcloud --quiet iam service-accounts delete "$SA_EMAIL" >>"$OUTFILE" 2>&1
  else
    printf "That service account does not exist.\n"
    printf "That service account does not exist.\n" >>"$OUTFILE"
  fi
}

# ====================================================================

check_required_commands gcloud
check_shell_variables CRUN_PROJECT CRUN_REGION SERVICE_ROOT

# derived variables
SERVICE_ACCOUNT="${SERVICE_ROOT}"
#SA_EMAIL="${SERVICE_ROOT}@${PROJECT}.iam.gserviceaccount.com"
SERVICE="${SERVICE_ROOT}-${example_name}"

printf "Logging to %s\n" "$OUTFILE"
printf "gcloud --quiet run services describe \"${SERVICE}\" --project \"${CRUN_PROJECT}\" --region \"${CRUN_REGION}\"\n"
printf "gcloud --quiet run services describe \"${SERVICE}\" --project \"${CRUN_PROJECT}\" --region \"${CRUN_REGION}\"\n" >>"$OUTFILE"
if gcloud --quiet run services describe "${SERVICE}" --project "${CRUN_PROJECT}" --region "${CRUN_REGION}" >>"$OUTFILE" 2>&1; then
  printf "That service exists...\n"
  SA_EMAIL=$(gcloud run services describe "$SERVICE" --region=${CRUN_REGION} --format='value(spec.template.spec.serviceAccountName)')
  printf "Removing the service from Cloud Run\n"
  printf "Removing the service from Cloud Run\n" >>"$OUTFILE"
  echo "gcloud --quiet run services delete \"${SERVICE}\" --project \"${CRUN_PROJECT}\" --region \"${CRUN_REGION}\"" >>$OUTFILE
  gcloud --quiet run services delete "${SERVICE}" --project "${CRUN_PROJECT}" --region "${CRUN_REGION}"
  check_and_maybe_delete_sa
else
  printf "That service does not exist. Nothing to clean up.\n"
fi

clean_files
