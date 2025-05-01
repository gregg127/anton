rm -rf site
mkdocs build
docker build --platform linux/amd64,linux/arm64 -t harbor.golebiowski.dev/services/anton-docs:latest -f docker/Dockerfile .
docker push harbor.golebiowski.dev/services/anton-docs