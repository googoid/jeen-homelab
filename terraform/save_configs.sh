#!/usr/bin/env bash

mkdir -p ~/.kube ~/.talos
terraform output -raw kubeconfig  > ~/.kube/jeen.yaml
terraform output -raw talosconfig > ~/.talos/config

export KUBECONFIG=~/.kube/jeen.yaml
