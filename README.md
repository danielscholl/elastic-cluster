# Best Practices Elastic Search Cluster

This is a sample project for exploring best practices using a cluster running instances of elastic search that strives to implement the [best practices](https://learn.microsoft.com/en-us/azure/aks/best-practices) of Azure Kubernetes Service (AKS).


[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fdanielscholl%2Felastic-cluster%2Fmain%2Fazuredeploy.json)


### Best Practices for Cluster Security and Upgrades.

1. [x] Enable Threat Protection with [Defender for Containers](https://learn.microsoft.com/en-us/azure/defender-for-cloud/defender-for-containers-introduction).

    Enable Defender for Containers to help secure containers. Defender for Containers can assess cluster configurations and provide security recommendations, run vulnerability scans, and provide real-time protection and alerting for Kubernetes nodes and clusters.

2. [x] Use Microsoft Entra ID and Kubernetes role-based access control ([Kubernetes RBAC](https://learn.microsoft.com/en-us/azure/aks/concepts-identity)) to secure API server access.

    Secure access to the Kubernetes API server. To control access to the API server, integrate Kubernetes RBAC with Microsoft Entra ID. Enables MFA for API server access.

3. [x] Upgrade AKS clusters to the latest Kubernetes version with [Automatic Upgrades](https://learn.microsoft.com/en-us/azure/aks/auto-upgrade-cluster?tabs=azure-cli).

    Stay current on new features and bug fixes, with automated regular upgrades of the Kubernetes version in the AKS cluster.

4. [x] Keep nodes up to date and automatically apply [node os security](https://learn.microsoft.com/en-us/azure/aks/node-updates-kured) patches automatically.

    Linux nodes in AKS get security patches through their distro update channel nightly. 

5. [x] Use [Azure Linux](https://learn.microsoft.com/en-us/azure/aks/use-azure-linux) for the nodes.

    The Azure Linux Container Host is an operating system image that's optimized for running container workloads on Azure Kubernetes Service (AKS). Microsoft maintains the Azure Linux Container Host and based it on CBL-Mariner, an open-source Linux distribution created by Microsoft.

6. [x] Disable SSH access to the nodes using AKS Preview feature [DisableSSHPreview](https://learn.microsoft.com/en-us/azure/aks/manage-ssh-node-access?tabs=node-shell#disable-ssh-overview).

    To improve security and support your corporate security requirements or strategy, AKS supports disabling SSH (preview) both on the cluster and at the node pool level.

7. [x] Prohibit changes made directly to resources in the node resource group using AKS Preview feature [NRGLockdownPreview](https://learn.microsoft.com/en-us/azure/aks/node-resource-group-lockdown).

    Prevent changes from being made to the node resource group, can apply a deny assignment and block users from modifying resources created as part of the AKS cluster.

### Best Practices for Container Image Management and Security.

1. [x] Scan for and remediate image vulnerabilities.

    Verify the security of images and runtime used in applications being hosted in the cluster.

    > [!NOTE]
    > This solution is using the latest versions of Elastic Cluster operator but allows specific versions to be specified.

2. [ ] Automatically trigger and redeploy container images when a base image is updated.

    Use automation to build new images when the base image is updated. Since updated base images typically include security fixes, update any downstream application container images.

    > [!NOTE]
    > This solution uses flux but does not currently use the [image automation controller](https://fluxcd.io/docs/components/image-automation/).

3. [x] Remove any unused images from the node to reduce vulnerabilities using [Image Cleaner](https://learn.microsoft.com/en-us/azure/aks/image-cleaner)

    Perform automatic image identification and removal, which mitigates the risk of stale images and reduces the time required to clean them up.


### Best Practices for Pod Security

1. [ ] Use pod security context to limit access to processes and services or privilege escalation

    Run as a different user or group and limit access to the underlying node processes and services, define pod security context settings. Assign the least number of privileges required.

    > [!NOTE]
    > This solution does not currently use [App Armor](https://learn.microsoft.com/en-us/azure/aks/operator-best-practices-cluster-security?tabs=azure-cli#app-armor).

2. [x] Use a Microsoft Entra [Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview?tabs=dotnet) to authenticate the workload to Azure services.

    A workload identity is an identity used by an application running on a pod that can authenticate itself against other Azure services that support it, such as Storage or Key Vault.

3. [x] Use Azure Key Vault with [Secrets Store CSI Driver](https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver) to manage secrets at runtime.

    Secrets Store CSI Driver is an open-source CSI driver that lets you store secrets in Azure Key Vault and mount them as files for use by workloads running in your cluster.

4. [x] Use Policy to watch for and alert on best practices using [AKS Policy Deployment Safeguards](https://learn.microsoft.com/en-us/azure/aks/deployment-safeguards).

    Deployment safeguards enforce Kubernetes best practices in your AKS cluster through Azure Policy controls.



### Best Practices for Network Connectivity and Security.

1. [x] Use [Azure CNI Overlay](https://learn.microsoft.com/en-us/azure/aks/azure-cni-overlay?tabs=kubectl) for enhanced network security and performance.

    Cluster nodes are deployed into an Azure Virtual Network (VNet) subnet. Pods are assigned IP addresses from a private CIDR logically different from the VNet hosting the nodes. Pod and node traffic within the cluster use an Overlay network. Network Address Translation (NAT) uses the node's IP address to reach resources outside the cluster. 

2. [x] Use a managed [NAT Gateway](https://learn.microsoft.com/en-us/azure/aks/nat-gateway) to provide outbound access to the internet.

    NAT Gateway is a managed service that provides outbound internet connectivity for the AKS cluster which then allows network traffic isolation to other azure resources such as Key Vault with network firewall rules.

3. [x] Use a managed [App Routing](https://learn.microsoft.com/en-us/azure/aks/app-routing) or [Service Mesh](https://learn.microsoft.com/en-us/azure/aks/istio-about) add-on to route external traffic to the cluster.

    App Routing is an nginx ingress controller add-on for AKS that provides a fully integrated ingress controller for applications running in the cluster.


### Best practices for storage and backups

1. [x] Use [Azure Managed Disks](https://learn.microsoft.com/en-us/azure/aks/concepts-storage) for storage.

    Azure Managed Disks are block-level storage volumes that are attached to a VM for the purposes of storing data.

2. [x] Use [Azure AKS Backup](https://learn.microsoft.com/en-us/azure/backup/azure-kubernetes-service-backup-overview) to back up the cluster.

    Azure Backup is a fully managed backup service for Azure resources. It provides a secure and reliable way to back up and restore data from Azure resources.

### Best Practices for Deployment

1. [x] Use [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/) to deploy the infrastructure as code.

    Azure Verified Modules are pre-validated modules that are designed to work together seamlessly to deploy infrastructure as code.

2. [x] Use [Azure GitOps Configurations](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/gitops-aks/gitops-blueprint-aks) to deploy the workload applications.

    Azure GitOps Configurations are a set of tools and services that enable you to use Git as a single source of truth for your infrastructure and workload applications.

3. [x] Use [Application Configuration Provider](https://learn.microsoft.com/en-us/azure/azure-app-configuration/reference-kubernetes-provider?tabs=default) to manage feature flags and configuration information.

    Application Configuration Provider is a fully managed feature flag and configuration management service for applications running on AKS.

### Best Practices for Performance and Scalability

1. [x] Use [Node Auto Provisioning](https://learn.microsoft.com/en-us/azure/aks/node-autoprovision?tabs=azure-cli) to reduce the number of nodes in the cluster and optimize for cost.

    Node Auto Provisioning is a feature that automatically provisions nodes in the cluster based on the configuration specified in the node template.   


2. [x] Use AKS managed [KEDA](https://learn.microsoft.com/en-us/azure/aks/keda-about) to scale the cluster pods based on the workload.

    KEDA is a Kubernetes-based Event Driven Autoscaler. It provides a way to scale Kubernetes workloads based on events from external systems.


3. [x] Use [Vertical Pod Autoscaler](https://learn.microsoft.com/en-us/azure/aks/vertical-pod-autoscaler) to ensure the proper memory and cpu resources are allocated for pods.

    When configured, the VPA automatically sets resource requests and limits on containers per workload based on past usage. The VPA frees up CPU and Memory for other pods and helps ensure effective utilization of your AKS clusters. 

### Best Practices for Observability

> Note: Observability is not yet completed.

- Managed Prometheus
- Container Insights
- Azure Managed Grafana
- Container Insights Workbooks
- Azure Policy Dashboards
- Prometheus Alert Rules
- Azure Action Groups

## Supported Workloads

- Test Workload (Test Stamp)

- Elastic Search (Elastic Stamp)

- PostgreSql (PostgreSql Stamp) -- Not yet implemented.

- Redis (Redis Stamp) -- Not yet implemented.

- Airflow (Airflow Stamp) -- Not yet implemented.

## Register the feature flags

To use AKS Automatic in preview, you must register feature flags for other required features. Register the following flags using the [az feature register](https://learn.microsoft.com/en-us/cli/azure/feature?view=azure-cli-latest#az-feature-register) command.

```bash
az feature register --namespace Microsoft.ContainerService --name EnableAPIServerVnetIntegrationPreview
az feature register --namespace Microsoft.ContainerService --name NRGLockdownPreview
az feature register --namespace Microsoft.ContainerService --name SafeguardsPreview
az feature register --namespace Microsoft.ContainerService --name NodeAutoProvisioningPreview
az feature register --namespace Microsoft.ContainerService --name DisableSSHPreview
az feature register --namespace Microsoft.ContainerService --name AutomaticSKUPreview
```

Verify the registration status by using the [az feature show](https://learn.microsoft.com/en-us/cli/azure/feature?view=azure-cli-latest#az-feature-show) command. It takes a few minutes for the status to show *Registered*:

```bash
az feature show --namespace Microsoft.ContainerService --name AutomaticSKUPreview
```

When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider by using the [az provider register](https://learn.microsoft.com/en-us/cli/azure/provider?view=azure-cli-latest#az-provider-register) command:


#### Important Notes

- Ingress with valid certificates and DNS is not yet implemented.
- AKS Backup instances are not yet configured for backup feature flag.
- Bugs still exist in Private Software feature flag.
- Multiple instances of elastic search are not yet supported.

> Note: Backup requires Storage Accounts with `Allow Storage Account Key Access` -- Bad Practice.

> Note: Flux Configurations with AzureBlob requires SAS tokens to be used as managed identities are not yet supported using automation and can only work with manual configurations. -- Bad Practice.
