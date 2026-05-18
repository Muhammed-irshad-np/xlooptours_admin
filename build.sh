#!/bin/bash

# Vercel automatically sets the VERCEL_ENV variable
# It will be "production" for the main branch, and "preview" for other branches like development.

echo "Vercel Environment: $VERCEL_ENV"

if [ "$VERCEL_ENV" == "production" ]; then
  echo "Building for Production Database..."
  ./flutter/bin/flutter build web --release
else
  echo "Building for Development Database..."
  ./flutter/bin/flutter build web --release --dart-define=ENV=dev
fi
