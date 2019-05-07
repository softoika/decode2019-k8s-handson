#!/bin/bash
# decode2019のリソースグループを作成する
az group --name decode2019 --location japaneast
# リソースグループ上にKubernetesクラスターを作成する
az aks create --resource-group decode2019 --name k8s-handson --node-count 1 --generate-ssh-keys
# Kubernetesクラスターに接続するための認証情報を取得する
az aks get-credentials --name k8s-handson --resource-group decode2019
