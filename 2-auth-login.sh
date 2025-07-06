#!/bin/bash
# -*- mode:shell-script; coding:utf-8; -*-

set -e

source ./lib/utils.sh

printf "\nThis script signs you in, and grants permissions to read and write sheets to\n"
printf "any application that can read Application Default Credentials.\n\n"

check_required_commands gcloud

gcloud auth application-default login \
       --scopes openid,https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/drive

