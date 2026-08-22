locals {
  coredns_corefile = <<-COREFILE
    .:53 {
        errors
        health {
            lameduck 5s
        }
        ready
        kubernetes wsc2026.skills.local cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
  COREFILE
}

resource "kubernetes_config_map_v1_data" "coredns" {
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }
  data = {
    Corefile = local.coredns_corefile
  }
  field_manager = "terraform-wsc2026-coredns"
  force         = true
}

resource "kubernetes_annotations" "coredns_rollout" {
  api_version = "apps/v1"
  kind        = "Deployment"
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }
  template_annotations = {
    "wsc2026/coredns-config" = sha256(local.coredns_corefile)
  }
  field_manager = "terraform-wsc2026-coredns"
  force         = true
  depends_on    = [kubernetes_config_map_v1_data.coredns]
}
