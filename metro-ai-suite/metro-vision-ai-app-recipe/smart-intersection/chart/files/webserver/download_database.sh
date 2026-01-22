#!/bin/bash

if [ -f /data/smart-intersection-ri.tar.bz2 ]; then
  echo "File exists: /data/smart-intersection-ri.tar.bz2"
else
  echo "File does NOT exist: /data/smart-intersection-ri.tar.bz2"
  echo "Downloading file from GitHub..."
  apk add --no-cache wget
  {{- if eq .Values.gitSource.type "tag" }}
  wget -O /data/smart-intersection-ri.tar.bz2 "https://github.com/open-edge-platform/edge-ai-suites/raw/refs/tags/{{ .Values.gitSource.ref }}/metro-ai-suite/metro-vision-ai-app-recipe/smart-intersection/src/webserver/smart-intersection-ri.tar.bz2"
  {{- else }}
  wget -O /data/smart-intersection-ri.tar.bz2 "https://github.com/open-edge-platform/edge-ai-suites/raw/refs/heads/{{ .Values.gitSource.ref }}/metro-ai-suite/metro-vision-ai-app-recipe/smart-intersection/src/webserver/smart-intersection-ri.tar.bz2"
  {{- end }}
  if [ $? -eq 0 ]; then
    echo "File downloaded successfully to /data/smart-intersection-ri.tar.bz2"
  else
    echo "Failed to download file"
    exit 1
  fi
fi
