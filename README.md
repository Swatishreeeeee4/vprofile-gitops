# VProfile GitOps: GitHub Actions → GHCR → Argo CD → Amazon EKS

End-to-end GitOps delivery of a multi-tier Java app. A code push builds, tests, scans and publishes container
images; the pipeline then **commits the new image tag to the Helm chart**, and **Argo CD** (running in EKS)
deploys whatever Git says. The cluster itself is created with **Terraform**.

> Final project of the *Decoding DevOps* course (Imran Teli, Udemy), redesigned by me to avoid long-lived cloud
> credentials in CI and to fit a restricted AWS account. See **Design decisions**.

## Architecture

```
 developer ──git push──▶ GitHub (this repo)
                            │
                            ▼  GitHub Actions (.github/workflows/ci.yml)
            ┌───────────────┼──────────────────────────┐
            │ test: mvn package (unit tests)            │
            │ security-scan: Trivy fs (vulns, secrets, misconfig)
            │ images: build & push app/db/web → ghcr.io (GITHUB_TOKEN)
            │         + Trivy image scan                │
            │ update-helm: commit new tag to helm/vprofile/values.yaml
            └───────────────┬──────────────────────────┘
                            │  (Git is the source of truth)
                            ▼
   Amazon EKS (Terraform: terraform/)   Argo CD watches helm/vprofile → auto-sync, prune, self-heal
     namespace vprofile:
       vproweb (Nginx, Service type LoadBalancer) ──▶ vproapp (Tomcat, readiness/liveness probes)
            vprodb (MySQL, PVC on EBS gp3) · vprocache01 (Memcached) · vpromq01 (RabbitMQ)
```

## Repository layout

| Path | What |
|---|---|
| `src/`, `pom.xml` | Java application (Spring MVC) |
| `Docker-files/{app,db,web}` | Multi-stage app image, MySQL image with schema, Nginx reverse proxy |
| `.github/workflows/ci.yml` | CI: test → scan → images → bump Helm tag |
| `helm/vprofile/` | Helm chart: Deployments, Services, PVC, StorageClass, probes, init container |
| `argocd/vprofile-app.yaml` | Argo CD Application (automated sync, prune, self-heal) |
| `terraform/` | VPC (public subnets only), EKS 1.37, managed node group, EBS CSI via Pod Identity |

## How to run

```bash
# 1. Infrastructure (~15 min)
cd terraform && terraform init && terraform apply
aws eks update-kubeconfig --name vprofile-eks --region ap-southeast-2

# 2. Argo CD
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd -n argocd --create-namespace

# 3. DB secret (kept out of Git) + the Application
kubectl create namespace vprofile
kubectl -n vprofile create secret generic vprofile-db-secret --from-literal=db-pass=<password>
kubectl apply -f argocd/vprofile-app.yaml

# 4. App URL and Argo CD UI
kubectl -n vprofile get svc vproweb          # EXTERNAL-IP = load balancer DNS → login admin_vp / admin_vp
kubectl -n argocd port-forward svc/argocd-server 8080:443   # https://localhost:8080, user admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# 5. Teardown: delete the App first so Kubernetes removes the load balancer and EBS volume
kubectl delete -f argocd/vprofile-app.yaml && helm uninstall argocd -n argocd
cd terraform && terraform destroy
```

## Design decisions (vs. the course)

- **No AWS keys or personal access tokens in GitHub.** Images go to **GHCR** with the built-in `GITHUB_TOKEN`,
  and the tag bump is a commit by the same token. The course stores long-lived AWS access keys and a PAT as secrets.
- **One repo, separate concerns by path**: CI triggers only on `src/`, `pom.xml`, `Docker-files/`; Argo CD
  watches only `helm/vprofile`. The tag-bump commit can't re-trigger CI (no loop).
- **EKS Pod Identity for the EBS CSI driver** instead of IRSA: the account's org policy blocks IAM OIDC
  providers, and Pod Identity doesn't need one.
- **Cost**: public subnets only (no NAT gateway), one t3.large node, Service type LoadBalancer instead of the
  AWS Load Balancer Controller + domain + ACM (which the course uses for HTTPS ingress).
- **Trivy** filesystem + image scans instead of a self-hosted SonarQube server.
- Kubernetes-native start ordering: an **init container** waits for MySQL; **readiness/liveness probes** on Tomcat;
  MySQL on a **PVC** with `Recreate` strategy.

## Known lab shortcuts

- The app reads its DB password from `application.properties`, so the Kubernetes Secret must match it.
  Next step: externalise it (environment variable / mounted secret) and use External Secrets + AWS Secrets Manager.
- HTTP only; for HTTPS add the AWS Load Balancer Controller + an Ingress with an ACM certificate.
- Terraform state is local; a team setup uses an S3 backend with locking.

## Tech

GitHub Actions · GHCR · Trivy · Docker (multi-stage) · Helm · Argo CD · Kubernetes · Amazon EKS · Terraform ·
EBS CSI / Pod Identity · Java 17/21 · Maven · Tomcat · MySQL · Memcached · RabbitMQ
