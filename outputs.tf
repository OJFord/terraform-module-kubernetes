output "cluster_id" {
  description = "Terraform ID bound to the cluster lifetime, i.e. change <=> kubeadm init has run"
  value       = null_resource.cluster.id
}

output "kubeconfig" {
  description = "The cluster admin.conf, aka kubeconfig YAML file contents"
  value       = module.kubeconfig.content
}
