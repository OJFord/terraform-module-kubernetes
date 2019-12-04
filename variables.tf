variable "bootstrap_token" {
  description = "https://godoc.org/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm/v1beta2#BootstrapToken"
  type        = string
}

variable "masters" {
  description = "Information about the hosts to configure as master nodes"
  type = list(object({
    id          = string
    no_schedule = bool
    ssh_host    = string
    ssh_user    = string
  }))
}

variable "workers" {
  description = "Information about the hosts to configure as workers nodes"
  type = list(object({
    id       = string
    ssh_host = string
    ssh_user = string
  }))
}

variable "apiserver_advertise_address" {
  description = "https://godoc.org/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm/v1beta2#InitConfiguration"
  type        = string
  default     = ""
}

variable "control_plane_endpoint" {
  description = "https://godoc.org/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm/v1beta2#ClusterConfiguration"
  type        = string
  default     = ""
}

variable "kubeadm_init_extra_args" {
  description = "Extra arguments to kubeadm init"
  type        = list(string)
  default     = []
}

variable "kubeadm_join_master_extra_args" {
  description = "Extra arguments to kubeadm join --control-plane"
  type        = list(string)
  default     = []
}

variable "kubeadm_join_worker_extra_args" {
  description = "Extra arguments to kubeadm join"
  type        = list(string)
  default     = []
}

variable "pod_subnet" {
  description = "https://godoc.org/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm/v1beta2#Networking"
  type        = string
  default     = ""
}

variable "service_subnet" {
  description = "https://godoc.org/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm/v1beta2#Networking"
  type        = string
  default     = ""
}
