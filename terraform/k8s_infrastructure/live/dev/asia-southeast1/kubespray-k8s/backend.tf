terraform {
  backend "local" {
    path = "../../../../state/dev/asia-southeast1/kubespray-k8s.tfstate"
  }
}
