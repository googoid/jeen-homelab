# Cilium CNI (eBPF), installed via Helm once the cluster is bootstrapped and the
# kubeconfig exists. Talos's default CNI + kube-proxy are disabled in the
# control-plane config (talos.tf), so nodes stay NotReady until this lands.
#
# Talos specifics baked into the values below:
#   - cgroup.autoMount=false + hostRoot=/sys/fs/cgroup: Talos already mounts the
#     cgroup2 fs, so Cilium must not try to mount its own.
#   - securityContext.capabilities: Talos runs Cilium unprivileged, so the agent
#     and clean-state init container need their capabilities listed explicitly.
#   - kubeProxyReplacement + k8sServiceHost=localhost:7445: reach the API server
#     via Talos KubePrism (a per-node API proxy, enabled by default), which is up
#     independent of CNI/VIP — avoids the bootstrap chicken-and-egg.
resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = var.cilium_version
  namespace  = var.cilium_namespace

  # kube-system always exists; only create the namespace if it's customized.
  create_namespace = var.cilium_namespace != "kube-system"

  # Cilium is what makes nodes Ready, so give the rollout room to converge.
  wait    = true
  timeout = 600

  values = [yamlencode({
    ipam                 = { mode = "kubernetes" }
    kubeProxyReplacement = true
    k8sServiceHost       = "localhost"
    k8sServicePort       = 7445

    cgroup = {
      autoMount = { enabled = false }
      hostRoot  = "/sys/fs/cgroup"
    }

    securityContext = {
      capabilities = {
        ciliumAgent = [
          "CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN",
          "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID",
        ]
        cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
      }
    }

    hubble = {
      relay = { enabled = true }
      ui    = { enabled = true }
    }

    # L2 announcements + LB IPAM so Service type=LoadBalancer gets a VIP from the
    # 10.66.6.0/24 host-only net (no cloud LB). Pool + policy live in Flux
    # (infrastructure/configs/cilium-lb). L2 raises API usage, so the default
    # client rate limit (5/10) is bumped. Keep in sync with the Flux HelmRelease.
    l2announcements = { enabled = true }
    k8sClientRateLimit = {
      qps   = 20
      burst = 40
    }
  })]

  depends_on = [talos_cluster_kubeconfig.this]
}
