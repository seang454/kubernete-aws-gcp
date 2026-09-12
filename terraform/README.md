  Run these commands on any master node where you want to use kubectl without sudo:

    mkdir -p ~/.kube
    sudo cp -f /etc/kubernetes/admin.conf ~/.kube/config
    sudo chown $(id -u):$(id -g) ~/.kube/config
    chmod 600 ~/.kube/config

  ### Or as a single copy-paste one-liner:

    mkdir -p ~/.kube && sudo cp -f /etc/kubernetes/admin.conf ~/.kube/config && sudo chown $(id -u):$(id -g) ~/.kube/config &&
  chmod 600 ~/.kube/config

  Then verify it works:

    kubectl get nodes -A