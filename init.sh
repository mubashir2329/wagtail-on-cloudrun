#!/bin/bash

PROJECT_ID=wagtail-demo-mubashir
REGION=us-central1

gcloud config set project $PROJECT_ID
gcloud auth list # confirm that correct project is selected

# enable cloud API's
gcloud services enable \
  run.googleapis.com \
  sql-component.googleapis.com \
  sqladmin.googleapis.com \
  compute.googleapis.com \
  cloudbuild.googleapis.com \
  secretmanager.googleapis.com