#!/bin/bash
VERSION=1.1
IMAGE_NAME=harbor.golebiowski.dev/services/anton-docs

log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

log "Cleaning up old site directory..."
rm -rf site

log "Building MkDocs site..."
mkdocs build

log "Building Docker image with version $VERSION..."
docker build --platform linux/amd64,linux/arm64 --build-arg VERSION="$VERSION" -t "$IMAGE_NAME:$VERSION" -f Dockerfile .

log "Pushing Docker image to registry..."
docker push "$IMAGE_NAME:$VERSION"

log "Updating version in kustomization..."
sed -i '' "s|$IMAGE_NAME:.*|$IMAGE_NAME:$VERSION|" kustomization/deployment.yaml

log "Commiting version to the repostiory..."
git add deploy-docs.sh
git add kustomization/deployment.yaml
git commit -m "Release documentation version $VERSION"

log "Deployment completed successfully."