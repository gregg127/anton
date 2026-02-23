#!/usr/bin/env bash

VERSION=1.2
IMAGE_NAME=harbor.golebiowski.dev/services/anton-docs

log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

log_error() {
  echo -e "\033[31m$(date +"%Y-%m-%d %H:%M:%S") - Error: $1\033[0m" >&2
}

log "Cleaning up old site directory..."
rm -rf site

log "Building MkDocs site..."
mkdocs build

# Detect OS and set appropriate platforms
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORMS="linux/amd64,linux/arm64"
    log "Detected macOS - building for multiple platforms: $PLATFORMS"
else
    PLATFORMS="linux/amd64"
    log "Detected Linux - building for single platform: $PLATFORMS"
fi

if ! docker info > /dev/null 2>&1; then
    log_error "Docker daemon is not running"
    exit 1
fi

log "Building Docker image with version "$VERSION" using buildx..."
docker buildx build \
  --platform "$PLATFORMS" \
  --build-arg VERSION="$VERSION" \
  --tag "$IMAGE_NAME:$VERSION" \
  -f Dockerfile .

log "Loading Docker image into local Docker registry..."
docker buildx build --load -t $IMAGE_NAME:$VERSION .

log "Pushing Docker image to remote registry..."
if ! docker push "$IMAGE_NAME:$VERSION" --platform linux/amd64; then
    log_error "Failed to push Docker image"
    exit 1
fi

log "Updating version in kustomization..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|$IMAGE_NAME:.*|$IMAGE_NAME:$VERSION|" kustomization/deployment.yaml
else
    sed -i "s|$IMAGE_NAME:.*|$IMAGE_NAME:$VERSION|" kustomization/deployment.yaml
fi

log "Commiting version to the repostiory..."
git add deploy-docs.sh
git add kustomization/deployment.yaml
git commit -m "Release documentation version $VERSION"

log "Deployment completed successfully."
