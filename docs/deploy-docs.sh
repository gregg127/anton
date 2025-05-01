rm -rf site
mkdocs build
docker compose build
docker compose push