# Anton - Homelab Kubernetes Cluster

> [!NOTE]
> 🚧 **Project Status: Active Development** 🚧
>

This repository contains the complete configuration and documentation for my homelab Kubernetes cluster. The cluster runs on Talos Linux and serves as a learning platform and hosting environment for various services and applications that I create.

## Repository Structure

```
anton-config/
├── cluster-config/        # Talos configuration files and patches
├── cluster-resources/     # Kubernetes resources and configurations
│   ├── infrastructure/    # Core infrastructure components
│   └── services/          # Application services
└── docs/                  # Full documentation and guides
```

## Documentation

The documentation is published at [anton.golebiowski.dev](https://anton.golebiowski.dev).

For a complete setup guide, refer to the [Quickstart](https://anton.golebiowski.dev/99_quickstart) documentation. For detailed, step-by-step instructions and explanations, start with the [Introduction](https://anton.golebiowski.dev).

Full documentation is available in the `docs/` directory and can be served locally using:

```bash
./serve-docs.sh
```
