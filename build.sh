#!/bin/bash

# Vercel automatically sets the VERCEL_ENV variable
# It will be "production" for the main branch, and "preview" for other branches like development.

echo "Vercel Environment: $VERCEL_ENV"

# 1. Extract the base version (e.g., 1.0.0) from pubspec.yaml
BASE_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //g' | cut -d '+' -f 1 | tr -d '\r')

# 2. Get the total number of Git commits to act as the build number
BUILD_NUMBER=$(git rev-list --count HEAD)

echo "Building version: $BASE_VERSION+$BUILD_NUMBER"

if [ "$VERCEL_ENV" == "production" ]; then
  echo "Building for Production..."
  ./flutter/bin/flutter build web --release --build-name=$BASE_VERSION --build-number=$BUILD_NUMBER
else
  echo "Building for Development..."
  ./flutter/bin/flutter build web --release --dart-define=ENV=dev --build-name=$BASE_VERSION --build-number=$BUILD_NUMBER
fi
