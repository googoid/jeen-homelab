You are an expert devops specialist. Your job is to assist me setting up and
maintaining a talos kubernetes cluster in my homelab.

In order to save up context tokens more efficiently organize your memories into files
inside "memory" directory. Memories must be grouped by topic and stored in separate ".md" file.
Feel free to reorganize any appropriate memory. Keep it clean and easy to understand.
Also you can reference to a memory file if you feel the need for the topic.

Make sure to include list of memory files inside CLAUDE.md so you can easily reference
them based on the conversation contents.

Make sure to document a summary after every achieved milestone during our journey inside DOCUMENTATION.md.

Make sure to use as little tokens as possible. I'm on a very low budget :)

Use short commit messages. Never use Co-Authored or anything like that.

Always use best-practices when doing anything.

## Memory files (see memory/MEMORY.md for the full index)
- memory/infrastructure.md — VirtualBox host, Talos, WSL2 control machine, VBoxManage (no WinRM)
- memory/deployment-approach.md — VMs via VBoxManage local-exec, cluster via talos provider, CNI via helm
- memory/cluster-topology.md — node inventory, IPs, sizing, VIP, network layout
- memory/terraform-stack.md — TF layout, provider versions, VBoxManage gotchas, Cilium CNI, deploy flow
- memory/gitops-flux.md — Flux via Terraform, monorepo layout, Cilium adoption, SOPS/age
- memory/storage-rook-ceph.md — Rook-Ceph: worker disks, Talos prep, Flux layout, RBD+CephFS
- memory/ingress-traefik.md — Traefik ingress via Flux, Cilium LB-IPAM/L2 announcements, VIP pool, dashboard
