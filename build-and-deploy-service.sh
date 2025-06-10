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
SA_REQUIRED_ROLES=("roles/storage.objectViewer" "roles/storage.objectCreator" "roles/storage.objectUser")

check_and_maybe_create_sa() {
  local ROLE ARR
  printf "Checking for service account %s...\n" "$SA_EMAIL"
  printf "Checking for service account %s...\n" "$SA_EMAIL" >>"$OUTFILE"
  echo "gcloud iam service-accounts describe \"$SA_EMAIL\" --project=\"$PROJECT\" --quiet" >>"$OUTFILE"
  if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT" --quiet >>"$OUTFILE" 2>&1; then
    printf "That service account exists...\n"
  else
    printf "Creating service account %s ...\n" "${SERVICE_ACCOUNT}"
    printf "Creating service account %s...\n" "${SERVICE_ACCOUNT}" >>"$OUTFILE"
    echo "gcloud iam service-accounts create \"${SERVICE_ACCOUNT}\" --project=\"${PROJECT}\" --quiet" >>"$OUTFILE"
    gcloud iam service-accounts create "${SERVICE_ACCOUNT}" --project="${PROJECT}" --quiet >>"$OUTFILE" 2>&1

    if [[ ${#SA_REQUIRED_ROLES[@]} -ne 0 ]]; then
      printf "There can be errors if all these changes happen too quickly, so we need to sleep a bit...\n"
      sleep 12
    fi
  fi
}

clean_files() {
  rm -f "${example_name}/*.*~"
  rm -fr "${example_name}/bin"
  rm -fr "${example_name}/obj"
}

check_shell_variables() {
  local MISSING_ENV_VARS
  MISSING_ENV_VARS=()
  for var_name in "$@"; do
    if [[ -z "${!var_name}" ]]; then
      MISSING_ENV_VARS+=("$var_name")
    fi
  done

  [[ ${#MISSING_ENV_VARS[@]} -ne 0 ]] && {
    printf -v joined '%s,' "${MISSING_ENV_VARS[@]}"
    printf "You must set these environment variables: %s\n" "${joined%,}"
    exit 1
  }

  printf "Settings in use:\n"
  for var_name in "$@"; do
    printf "  %s=%s\n" "$var_name" "${!var_name}"
  done
  printf "\n"
}

check_required_commands() {
  local missing
  missing=()
  for cmd in "$@"; do
    #printf "checking %s\n" "$cmd"
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  if [[ -n "$missing" ]]; then
    printf -v joined '%s,' "${missing[@]}"
    printf "\n\nThese commands are missing; they must be available on path: %s\nExiting.\n" "${joined%,}"
    exit 1
  fi
}

# ====================================================================

example_name="server"
check_required_commands gcloud grep sed tr
check_shell_variables PROJECT REGION SERVICE_ROOT SHEET_ID

# derived variables
SERVICE_ACCOUNT="${SERVICE_ROOT}"
SA_EMAIL="${SERVICE_ROOT}@${PROJECT}.iam.gserviceaccount.com"
SERVICE="${SERVICE_ROOT}-${example_name}"

printf "Logging to %s\n" "$OUTFILE"

check_and_maybe_create_sa

clean_files

#Find the service account identified by <project-number>@cloudbuild.gserviceaccount.com;
#Edit the service account and add the Cloud Functions Admin and Service Account User roles.

printf "Deploying the service to Cloud run\n"
printf "Deploying the service to Cloud run\n" >>"$OUTFILE"
echo "gcloud run deploy \"${SERVICE}\" \
  --source \".\" \
  --project \"${PROJECT}\" \
  --concurrency 5 \
  --cpu 1 \
  --memory '512Mi' \
  --min-instances 0 \
  --max-instances 1 \
  --set-env-vars KEY1=VALUE1,KEY2=VALUE2 \
  --allow-unauthenticated \
  --update-build-env-vars=\"GCLOUD_BUILD=1\" \
  --region \"${REGION}\" \
  --service-account \"${SA_EMAIL}\" \
  --timeout 380" >>$OUTFILE

# Note: mounting filesystems, such as GCS buckets, implicitly requires the gen2
# runtime.  And in that case, must specify 512Mi memory minimum.
gcloud run deploy "${SERVICE}" \
  --source "./" \
  --project "${PROJECT}" \
  --concurrency 5 \
  --cpu 1 \
  --memory '512Mi' \
  --min-instances 0 \
  --max-instances 1 \
  --set-env-vars SA_EMAIL="${SA_EMAIL}",PROJECT_ID="$PROJECT",SHEET_ID="${SHEET_ID}" \
  --allow-unauthenticated \
  --update-build-env-vars="GCLOUD_BUILD=1" \
  --region "${REGION}" \
  --service-account "${SA_EMAIL}" \
  --timeout 380 


