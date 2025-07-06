#!/bin/bash
# -*- mode:shell-script; coding:utf-8; -*-

set -e

source ./lib/utils.sh

check_shell_variables CLOUDRUN_PROJECT_ID CLOUDRUN_SERVICE_NAME
check_required_commands gcloud

printf "\nThis script makes sure the required services are enabled in your project.\n"

gcloud services enable --project "$CLOUDRUN_PROJECT_ID" \
  sheets.googleapis.com \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  artifactregistry.googleapis.com
