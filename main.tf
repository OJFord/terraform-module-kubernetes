locals {
  masters_idx = toset(range(length(var.masters)))
  masters     = { for idx in local.masters_idx : idx => var.masters[idx] }

  workers_idx = toset(range(length(var.workers)))
  workers     = { for idx in local.workers_idx : idx => var.workers[idx] }

  define_cluster_ready = <<EOD
    cluster_ready() {
      if [ $${CLUSTER_READY:-1} -gt 0 ]; then
        curl --silent 'https://${var.control_plane_endpoint}:6443' | grep '"kind": "Status"' >/dev/null
        CLUSTER_READY=$?
      fi
      return $CLUSTER_READY
    }
EOD

  kubeadm_config_file      = "/tmp/kubeadm-conf.yaml"
  kubeadm_join_script_file = "/tmp/kubeadm-join"

  # Certs paths source: https://kubernetes.io/docs/setup/best-practices/certificates
  ca_cert = "/etc/kubernetes/pki/ca.crt"
  certs = [
    local.ca_cert,
    "/etc/kubernetes/pki/ca.key",
    "/etc/kubernetes/pki/etcd/ca.crt",
    "/etc/kubernetes/pki/etcd/ca.key",
    "/etc/kubernetes/pki/front-proxy-ca.crt",
    "/etc/kubernetes/pki/front-proxy-ca.key",
    "/etc/kubernetes/pki/sa.key",
    "/etc/kubernetes/pki/sa.pub",
  ]
}

resource "null_resource" "cluster" {
  # Init on (arbitrarily) the first master.
  # *Do not* trigger on changes to it,
  #   so we don't re-init if the node is replaced.
  connection {
    host = local.masters[0].ssh_host
    user = local.masters[0].ssh_user
  }

  provisioner "file" {
    content     = <<EOC
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
controlPlaneEndpoint: ${var.control_plane_endpoint}
networking:
  podSubnet: ${var.pod_subnet}
  serviceSubnet: ${var.service_subnet}
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
bootstrapTokens:
  - token: ${var.bootstrap_token}
localAPIEndpoint:
  advertiseAddress: ${var.apiserver_advertise_address}
  bindPort: 6443
EOC
    destination = local.kubeadm_config_file
  }

  provisioner "remote-exec" {
    inline = [
      "kubeadm init --config=${local.kubeadm_config_file} ${join(" ", var.kubeadm_init_extra_args)}",
    ]
  }

  provisioner "remote-exec" {
    when = "destroy"
    inline = [
      "kubeadm reset --force",
    ]
  }
}

resource "null_resource" "certs" {
  for_each = local.masters

  triggers = {
    master  = each.value.id
    cluster = null_resource.cluster.id
  }

  depends_on = [
    null_resource.cluster,
  ]

  connection {
    host = each.value.ssh_host
    user = each.value.ssh_user
  }

  provisioner "local-exec" {
    command = <<EOC
      joiner='${each.value.ssh_user}@${each.value.ssh_host}'

      >&2 echo Seeking certs...
      for source in ${join(" ", [for m in local.masters : "${m.ssh_user}@${m.ssh_host}"])}; do
        if ssh "$source" test -f '${local.certs[0]}'; then
          >&2 echo Found extant master with certificates

        %{for f in local.certs}
          ssh "$joiner" -- mkdir -p "$(dirname '${f}')"
          scp -3 "$source:${f}" "$joiner:${f}"
        %{endfor}
        fi
      done
EOC
  }

  provisioner "remote-exec" {
    inline = [
      "cp ${local.ca_cert} /usr/local/share/ca-certificates/k8s-apiserver.crt",
      "update-ca-certificates",
    ]
  }
}

resource "null_resource" "master" {
  for_each = local.masters

  triggers = {
    node = each.value.id
  }

  depends_on = [
    null_resource.cluster,
    null_resource.certs,
  ]

  connection {
    host = each.value.ssh_host
    user = each.value.ssh_user
  }

  provisioner "file" {
    content     = <<EOC
      #!/bin/sh
      set -e

      ${local.define_cluster_ready}
      while ! cluster_ready; do sleep 2; done

      kubeadm join --control-plane --token='${var.bootstrap_token}' \
        ${join(" ", var.kubeadm_join_master_extra_args)}
EOC
    destination = local.kubeadm_join_script_file
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 0100 ${local.kubeadm_join_script_file}",
      "${local.kubeadm_join_script_file}",
      "rm ${local.kubeadm_join_script_file}",
    ]
  }
}

resource "null_resource" "worker" {
  for_each = local.workers

  triggers = {
    node = each.value.id
  }

  depends_on = [
    null_resource.cluster,
  ]

  connection {
    host = each.value.ssh_host
    user = each.value.ssh_user
  }

  provisioner "file" {
    content     = <<EOC
      #!/bin/sh
      set -e

      ${local.define_cluster_ready}
      while ! cluster_ready; do sleep 2; done

      kubeadm join --token='${var.bootstrap_token}' \
        ${join(" ", var.kubeadm_join_worker_extra_args)}
EOC
    destination = local.kubeadm_join_script_file
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 0100 ${local.kubeadm_join_script_file}",
      "${local.kubeadm_join_script_file}",
      "rm ${local.kubeadm_join_script_file}",
    ]
  }

  provisioner "remote-exec" {
    when   = "destroy"
    inline = ["kubeadm reset --force"]
  }
}

module "kubeconfig" {
  source = "OJFord/ssh_file/module"

  connection = {
    host = local.masters[0].ssh_host
    user = local.masters[0].ssh_user
  }
  filename = "/etc/kubernetes/admin.conf"
}
