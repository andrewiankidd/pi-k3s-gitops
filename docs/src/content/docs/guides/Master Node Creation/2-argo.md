---
title: Argo CD
description: Hunting for gold
draft: true
---

<center>
    <img
        src="/pi-k3s-gitops/_image?href=%2F%40fs%2FC%3A%2Fgit%2Fpi-k3s-gitops%2Fdocs%2Fsrc%2Fassets%2Ftodo.png"
        style="height:250px"
    >
    <h3>TODO: still a WIP</h3>
</center>



### ArgoCD
TODO

ArgoCD documentation says:
> For Argo CD v1.9 and later, the initial password is available from a secret named argocd-initial-admin-secret.

```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Might take a while for argo to initialize, so I stuck this in a loop until it's ready
```
while kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d | grep -q '^Error'; do sleep 1; done; kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```


## app of apps & projects