# EKS DevSecOps Project

A hands-on AWS EKS project demonstrating how to build Kubernetes infrastructure with Terraform and deploy an application using Kubernetes, Helm, IRSA/OIDC, and the AWS Load Balancer Controller.

---

## 1. Project Overview

This project builds an Amazon EKS environment from scratch and exposes a Kubernetes application through an AWS Application Load Balancer (ALB).

### Main technologies

* AWS
* Terraform
* Amazon VPC
* Amazon EKS
* Kubernetes
* Helm
* AWS Load Balancer Controller
* IAM
* OIDC / IRSA
* Application Load Balancer
* NGINX

---

# 2. Architecture

```text
                         INTERNET
                            |
                            | HTTP :80
                            v
                 +----------------------+
                 | AWS Application      |
                 | Load Balancer (ALB)  |
                 +----------+-----------+
                            |
                       Target Group
                            |
                 +----------+----------+
                 |                     |
                 v                     v
          Pod 10.0.2.82          Pod 10.0.3.88
           demo-app                demo-app
                 |                     |
                 +----------+----------+
                            |
                            v
                    demo-service
                     ClusterIP
                            |
                            v
                     EKS Cluster
                            |
             +--------------+--------------+
             |                             |
             v                             v
          Node 1                         Node 2
        Private Subnet                 Private Subnet
```

---

# 3. AWS Infrastructure

Terraform creates the AWS infrastructure.

## VPC

```text
VPC
CIDR: 10.0.0.0/16
```

## Subnets

Two public and two private subnets are created across two Availability Zones.

```text
VPC
|
+-- Public Subnet AZ-1
|
+-- Public Subnet AZ-2
|
+-- Private Subnet AZ-1
|
+-- Private Subnet AZ-2
```

### Public subnet

Used for resources that require internet-facing connectivity, such as:

* NAT Gateway
* Internet-facing load balancer

### Private subnet

Used for:

* EKS worker nodes
* Kubernetes workloads

Worker nodes do not require public IP addresses.

---

# 4. Internet Gateway

The VPC has an Internet Gateway.

```text
Internet
   |
   v
Internet Gateway
   |
   v
Public Subnets
```

The public route table contains:

```text
0.0.0.0/0 -> Internet Gateway
```

---

# 5. NAT Gateway

Two NAT Gateways are created.

```text
Private Subnet AZ-1
       |
       v
NAT Gateway AZ-1
       |
       v
Internet Gateway
       |
       v
Internet
```

and:

```text
Private Subnet AZ-2
       |
       v
NAT Gateway AZ-2
       |
       v
Internet Gateway
       |
       v
Internet
```

This allows private resources to access the internet without having public IP addresses.

---

# 6. EKS Cluster

Cluster name:

```text
test-eks-cluster
```

Region:

```text
ap-south-1
```

The EKS control plane is associated with the private subnets.

---

# 7. EKS Managed Node Group

Node group:

```text
test-node-group
```

Instance type:

```text
t3.medium
```

Scaling:

```text
Desired: 2
Minimum: 1
Maximum: 3
```

Nodes are deployed in private subnets.

Example:

```text
Node 1
10.0.2.x

Node 2
10.0.3.x
```

---

# 8. EKS Add-ons

The following EKS add-ons are installed:

```text
VPC CNI
CoreDNS
kube-proxy
```

### VPC CNI

Provides networking for Kubernetes pods.

### CoreDNS

Provides DNS resolution inside the Kubernetes cluster.

### kube-proxy

Provides Kubernetes Service networking on nodes.

---

# 9. OIDC Provider

An EKS OIDC provider was created.

Purpose:

Allow Kubernetes ServiceAccounts to assume AWS IAM roles.

Flow:

```text
Kubernetes ServiceAccount
          |
          v
      EKS OIDC
          |
          v
        AWS STS
          |
          v
       IAM Role
```

This is used for IRSA.

---

# 10. AWS Load Balancer Controller

The AWS Load Balancer Controller manages AWS Elastic Load Balancers from Kubernetes.

It watches Kubernetes resources such as:

```text
Ingress
Service
TargetGroupBinding
```

For this project, we use it to create an AWS Application Load Balancer from a Kubernetes Ingress.

---

# 11. IAM Policy

The AWS Load Balancer Controller uses:

```text
AWSLoadBalancerControllerIAMPolicy
```

This policy contains permissions required to interact with:

* EC2
* Elastic Load Balancing
* Security Groups
* ACM
* WAF
* Shield
* Other required AWS APIs

The existing AWS policy was reused rather than creating another copy.

---

# 12. IAM Role

Terraform creates:

```text
aws-load-balancer-controller
```

IAM role.

The role trusts the EKS OIDC provider.

The trust relationship restricts access to:

```text
system:serviceaccount:kube-system:aws-load-balancer-controller
```

The important flow is:

```text
AWS Load Balancer Controller Pod
              |
              v
Kubernetes ServiceAccount
              |
              v
          OIDC / IRSA
              |
              v
       IAM Role
              |
              v
AWSLoadBalancerControllerIAMPolicy
```

---

# 13. Kubernetes ServiceAccount

Namespace:

```text
kube-system
```

ServiceAccount:

```text
aws-load-balancer-controller
```

The ServiceAccount is annotated with the IAM role:

```text
eks.amazonaws.com/role-arn
```

This allows the controller to obtain AWS permissions without storing AWS access keys inside Kubernetes.

---

# 14. Helm

Helm is used to install the AWS Load Balancer Controller.

Repository:

```text
https://aws.github.io/eks-charts
```

The controller is installed into:

```text
kube-system
```

The existing ServiceAccount is used:

```text
serviceAccount.create=false
serviceAccount.name=aws-load-balancer-controller
```

---

# 15. AWS Load Balancer Controller

The controller runs with two replicas.

Example:

```text
aws-load-balancer-controller
|
+-- Pod 1 -> Running
|
+-- Pod 2 -> Running
```

Two replicas provide controller availability.

---

# 16. Application Deployment

A sample NGINX application is deployed.

Deployment:

```text
demo-app
```

Replicas:

```text
2
```

Example:

```text
demo-app
|
+-- Pod 1
|   IP: 10.0.2.82
|
+-- Pod 2
    IP: 10.0.3.88
```

---

# 17. Kubernetes Service

Service:

```text
demo-service
```

Type:

```text
ClusterIP
```

Port:

```text
80
```

The Service selects pods using:

```yaml
selector:
  app: demo-app
```

Flow:

```text
demo-service
     |
     +----> Pod 1
     |
     +----> Pod 2
```

ClusterIP is internal to the Kubernetes cluster.

It is not directly exposed to the internet.

---

# 18. Kubernetes Ingress

Ingress:

```text
demo-ingress
```

Ingress class:

```text
alb
```

Important annotations:

```yaml
alb.ingress.kubernetes.io/scheme: internet-facing
alb.ingress.kubernetes.io/target-type: ip
```

### `internet-facing`

Creates a publicly accessible ALB.

### `target-type: ip`

Registers Kubernetes pod IP addresses directly as ALB targets.

Example:

```text
ALB
 |
 +-- 10.0.2.82:80
 |
 +-- 10.0.3.88:80
```

---

# 19. Complete Request Flow

When a user sends:

```text
http://<ALB-DNS>
```

the request flows as:

```text
Internet
   |
   v
AWS Application Load Balancer
   |
   v
ALB Listener :80
   |
   v
Target Group
   |
   +-------------------+
   |                   |
   v                   v
Pod 10.0.2.82       Pod 10.0.3.88
   |                   |
   v                   v
demo-app             demo-app
```

---

# 20. Kubernetes Control Flow

The ALB is not created manually.

The process is:

```text
Kubernetes Ingress
        |
        v
AWS Load Balancer Controller
        |
        v
AWS APIs
        |
        +---- Create ALB
        |
        +---- Create Target Group
        |
        +---- Create Listener
        |
        +---- Create Listener Rules
        |
        +---- Register Pod IPs
```

---

# 21. Terraform vs Kubernetes/Helm

This project uses both Terraform and Kubernetes tools.

## Terraform

Used for infrastructure:

```text
VPC
Subnets
Route Tables
Internet Gateway
NAT Gateway
EKS
Node Group
IAM
OIDC
EKS Add-ons
```

## kubectl

Used for Kubernetes resources:

```text
Deployment
Pod
Service
Ingress
ServiceAccount
```

## Helm

Used for installing Kubernetes applications/controllers:

```text
AWS Load Balancer Controller
```

---

# 22. Useful Commands

## Check nodes

```bash
kubectl get nodes
```

## Check all pods

```bash
kubectl get pods -A
```

## Check application pods

```bash
kubectl get pods
```

## Check services

```bash
kubectl get svc
```

## Check ingress

```bash
kubectl get ingress
```

## Detailed ingress information

```bash
kubectl describe ingress demo-ingress
```

## Check AWS Load Balancer Controller

```bash
kubectl get pods \
  -n kube-system \
  -l app.kubernetes.io/name=aws-load-balancer-controller
```

## Check controller logs

```bash
kubectl logs \
  -n kube-system \
  -l app.kubernetes.io/name=aws-load-balancer-controller
```

## Check ALB

```bash
aws elbv2 describe-load-balancers \
  --region ap-south-1
```

---

# 23. Terraform Dependency Flow

The Terraform infrastructure can be visualized using:

```bash
terraform graph
```

To create an image using Graphviz:

```bash
terraform graph | dot -Tpng > terraform-graph.png
```

Open it on macOS:

```bash
open terraform-graph.png
```

---

# 24. Current Project Status

| Component                    | Status |
| ---------------------------- | ------ |
| AWS VPC                      | ✅      |
| Public Subnets               | ✅      |
| Private Subnets              | ✅      |
| Internet Gateway             | ✅      |
| NAT Gateways                 | ✅      |
| Route Tables                 | ✅      |
| EKS Cluster                  | ✅      |
| Managed Node Group           | ✅      |
| VPC CNI                      | ✅      |
| CoreDNS                      | ✅      |
| kube-proxy                   | ✅      |
| EKS OIDC Provider            | ✅      |
| IAM Policy                   | ✅      |
| IAM Role                     | ✅      |
| IRSA                         | ✅      |
| Helm                         | ✅      |
| AWS Load Balancer Controller | ✅      |
| Demo Deployment              | ✅      |
| Demo Service                 | ✅      |
| Kubernetes Ingress           | ✅      |
| AWS ALB                      | ✅      |
| ALB → Pod connectivity       | ✅      |

---

# 25. Lessons Learned

### 1. Terraform creates infrastructure

Terraform was responsible for creating the AWS infrastructure and IAM configuration.

### 2. Kubernetes manages workloads

Kubernetes manages:

```text
Pods
Deployments
Services
Ingress
```

### 3. Helm manages Kubernetes applications

Helm was used to install the AWS Load Balancer Controller.

### 4. IRSA avoids static AWS credentials

The controller does not need an AWS access key stored inside Kubernetes.

Instead:

```text
ServiceAccount
      ↓
OIDC
      ↓
IAM Role
      ↓
AWS Permissions
```

### 5. Ingress does not create an ALB by itself

The AWS Load Balancer Controller watches the Ingress and creates/configures the AWS ALB.

### 6. ClusterIP is internal

The application Service is:

```text
ClusterIP
```

The internet does not directly access it.

The ALB provides the external entry point.

### 7. IP target mode sends traffic directly to pods

With:

```yaml
alb.ingress.kubernetes.io/target-type: ip
```

the ALB target group contains pod IPs.

---

# 26. Next Planned Improvements

This README should be updated as the project grows.

Planned topics:

* [ ] HTTPS with ACM
* [ ] Route 53 DNS
* [ ] HTTPS redirect
* [ ] WAF
* [ ] Security group hardening
* [ ] Network policies
* [ ] Helm application deployment
* [ ] Argo CD
* [ ] GitHub/Bitbucket integration
* [ ] Jenkins CI pipeline
* [ ] Container image scanning
* [ ] Trivy
* [ ] SonarQube
* [ ] Secrets management
* [ ] External Secrets
* [ ] AWS Secrets Manager
* [ ] CloudWatch monitoring
* [ ] Prometheus
* [ ] Grafana
* [ ] HPA
* [ ] Karpenter
* [ ] Pod security
* [ ] RBAC
* [ ] Gateway API
* [ ] Dev/Staging/Production environments
* [ ] Terraform remote state
* [ ] Terraform state locking
* [ ] CI/CD for Terraform
* [ ] Disaster recovery

---

# 27. Final Architecture

```text
                         USER
                          |
                          v
                   Route 53 / DNS
                          |
                          v
                 AWS ALB :443/:80
                          |
                          v
                 AWS Load Balancer
                    Controller
                          |
                     IRSA/OIDC
                          |
                      IAM Role
                          |
                          v
                    EKS Cluster
                          |
                 Kubernetes Ingress
                          |
                          v
                    K8s Service
                    ClusterIP :80
                          |
                +---------+---------+
                |                   |
                v                   v
             Pod 1               Pod 2
           demo-app             demo-app
                |                   |
                +---------+---------+
                          |
                    Container
                     NGINX
```

---

## Project Goal

The final goal is to evolve this project into a production-style AWS DevSecOps platform demonstrating:

```text
Terraform
   ↓
AWS Infrastructure
   ↓
EKS
   ↓
Security / IAM / IRSA
   ↓
Kubernetes
   ↓
Helm
   ↓
CI/CD
   ↓
GitOps / Argo CD
   ↓
Security Scanning
   ↓
Monitoring
   ↓
Production Deployment
```
