# Argo CD hello example

A small example of deploying to Kubernetes with Argo CD. Argo CD reads the manifests in [`hello/`](hello/) from this GitHub repository and creates them in the local kind cluster: a `hello` namespace, an nginx Deployment with 2 pods, and a Service in front of them. After that you change the cluster by committing to Git, not by running `kubectl`.

Commands are for **cmd** and run from the repository root (`D:\Hobby\huggly`) unless a step says otherwise. They work the same in PowerShell, except for setting `KUBECONFIG`, which is covered in the [setup guide](../../../../docs/README.md#4-run-a-local-kubernetes-cluster).

## What's in this folder

```
examples/kubernetes/deploy/local/
  hello/               <- Argo CD watches this folder
    namespace.yaml
    deployment.yaml
    service.yaml
  argocd/
    hello-app.yaml     <- you apply this once with kubectl
```

| File | What it does | Applied by |
|---|---|---|
| `hello/namespace.yaml` | Creates the `hello` namespace | Argo CD, from Git |
| `hello/deployment.yaml` | Runs 2 nginx pods and replaces any that die | Argo CD, from Git |
| `hello/service.yaml` | Gives the pods one stable address inside the cluster | Argo CD, from Git |
| `argocd/hello-app.yaml` | An Argo CD `Application` that watches `hello/` on the `main` branch | You, once, with `kubectl apply` |

`hello-app.yaml` sits outside `hello/` on purpose. If it were inside the folder Argo CD watches, the app would try to manage its own definition.

`local` stands for the local kind cluster. Other environments would get their own folders next to it, such as `deploy/dev/`, each with its own Application.

If you move this folder, update `path:` in `argocd/hello-app.yaml` to match. Argo CD finds the manifests by that path in the GitHub repository.

## Before you start

You need the local cluster with Argo CD running. Follow [section 4 of the setup guide](../../../../docs/README.md#4-run-a-local-kubernetes-cluster), then check that `kubectl` reaches it:

```bat
kubectl get nodes
kubectl -n argocd get pods
```

Both nodes should be `Ready` and the Argo CD pods `Running`. If `kubectl` can't connect, set `KUBECONFIG` again in this cmd window:

```bat
cd /d D:\Hobby\huggly\src\Huggly.Core\Templates\Files\local-k8s
for /f "delims=" %i in ('terraform output -raw kubeconfig_path') do set "KUBECONFIG=%i"
cd /d D:\Hobby\huggly
```

## 1. Push the example to GitHub

Argo CD reads from `https://github.com/kkho/huggly` on the `main` branch, not from your PC. The files must be pushed before Argo CD can see them:

```bat
git add examples/kubernetes
git commit -m "Add Argo CD hello example"
git push
```

The repository is public, so Argo CD needs no Git credentials. A private repository would need to be added under **Settings → Repositories** in the Argo CD UI first.

## 2. Register the app with Argo CD

```bat
kubectl apply -f examples\kubernetes\deploy\local\argocd\hello-app.yaml
```

This is the only time you use `kubectl apply` for this example. From now on, every change goes through Git.

You may see `Warning: metadata.finalizers: ... prefer a domain-qualified finalizer name`. It's harmless: newer Kubernetes versions warn about finalizer names without a `/`, but this is the name Argo CD expects.

## 3. Check that it's deployed

```bat
kubectl -n argocd get application hello
kubectl -n hello get pods
```

The application should show `Synced` and `Healthy`, and two `hello-...` pods should be `Running`. This can take up to a minute while nginx is pulled.

In the Argo CD UI, the **hello** tile shows the resource tree: Namespace → Deployment → ReplicaSet → Pods. To open the UI, run this in a second cmd window, then browse to http://localhost:8081 and sign in as `admin`:

```bat
kubectl -n argocd port-forward svc/argocd-server 8081:80
```

Get the password from the `local-k8s` folder with `terraform output -raw argocd_admin_password`.

To see the nginx welcome page, run this in another cmd window, then browse to http://localhost:8082:

```bat
kubectl -n hello port-forward svc/hello 8082:80
```

## 4. Try the GitOps loop

**Change something through Git.** In `hello/deployment.yaml`, change `replicas: 2` to `replicas: 3`, then commit and push. Argo CD checks Git about every 3 minutes. To skip the wait, click **Refresh** on the app in the UI. A third pod appears:

```bat
kubectl -n hello get pods
```

**Watch Argo CD undo a manual change.** Scale the deployment by hand:

```bat
kubectl -n hello scale deployment hello --replicas=1
kubectl -n hello get pods
```

Within a few seconds Argo CD scales it back to the number in Git. This is `selfHeal: true` in `argocd/hello-app.yaml`.

**Roll back.** Undo your last commit and push:

```bat
git revert HEAD
git push
```

The replica count goes back to what it was.

## 5. Clean up

```bat
kubectl -n argocd delete application hello
```

The finalizer in `hello-app.yaml` makes this delete the `hello` namespace and everything in it as well. If you delete the namespace without deleting the Application first, Argo CD recreates it.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Application shows `Unknown` with `app path does not exist` | The files aren't on `main` on GitHub yet, or `path:` in `hello-app.yaml` doesn't match the folder | Push them, check `path:`, then click **Refresh** |
| Application shows `OutOfSync` after you pushed | Argo CD hasn't checked Git yet | Wait up to 3 minutes, or click **Refresh** |
| Pods stuck in `ImagePullBackOff` | The cluster can't download the nginx image | Check your network, then `kubectl -n hello describe pod <name>` for the exact error |
| `error: resource mapping not found for kind "Application"` | Argo CD isn't installed in the cluster you're connected to | Check `kubectl config current-context` and `KUBECONFIG`, then rerun the setup guide |
| `kubectl` says `connection refused` | The cluster stopped, usually after a restart | See [After restarting your PC](../../../../docs/README.md#after-restarting-your-pc) |

## Secrets

This repository is public. Never commit a Kubernetes `Secret` here: base64 is encoding, not encryption. For secrets in a GitOps setup, use a tool such as Sealed Secrets or External Secrets.
