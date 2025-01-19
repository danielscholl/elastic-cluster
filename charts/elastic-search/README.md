# Elasticsearch Helm Chart

This Helm chart deploys Elasticsearch and Kibana using the Elastic Cloud on Kubernetes (ECK) operator. It supports flexible deployment options from single-node to multi-node high availability configurations.


## Prerequisites

- Kubernetes cluster (AKS recommended)
- Helm 3.x
- ECK operator installed in the cluster
- For Azure integration:
  - Azure Storage Account
  - Azure App Configuration
  - Workload Identity configured (for Azure authentication)

## Installation

1. Install the chart:
   ```bash
   # Basic installation
   helm install elastic-search .

   # Installation with custom values
   helm install elastic-search . -f values.yaml
   ```

## Configuration

### Core Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `elasticVersion` | Elasticsearch version | Chart's appVersion |
| `elasticInstances` | Number of Elasticsearch instances | `1` |
| `zones` | Number of zones for HA deployment (1-3) | `1` |

### Storage Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `storage.size` | Storage size per node | `4Gi` |
| `storage.class` | Storage class | `managed-premium` |

### Node Placement

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nodeSelector` | Node selector for pod assignment | `nil` |

### Azure Integration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `azure.configEndpoint` | Azure App Configuration endpoint | `nil` |
| `azure.storageAccountName` | Azure Storage Account name | `nil` |
| `azure.storageAccountContainer` | Azure Storage container for snapshots | `el-snapshots` |

## Deployment Modes

Set `zones` parameter to configure resilience:

- `zones: 1` - Single node cluster (default, development/testing)
- `zones: 2` - Two node cluster (testing only, not for production)
- `zones: 3` - Three node cluster (recommended for production)