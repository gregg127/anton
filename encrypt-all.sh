./manage-secrets.sh encrypt cluster-config/patches/secrets.yaml
./manage-secrets.sh encrypt cluster-resources/ingress/anton-ingress.yaml
./manage-secrets.sh encrypt cluster-resources/ingress/cert-issuers/certificate-issuer-staging.yaml
./manage-secrets.sh encrypt cluster-resources/ingress/cert-issuers/certificate-issuer-prod.yaml