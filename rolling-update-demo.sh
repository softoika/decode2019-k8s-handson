#!/bin/bash

# Deploymentを作成
kubectl apply -f rolling-update-deployment.yaml

echo

# コンテナイメージを変更
kubectl set image deployment rolling-update-deployment hello-app-container=rhanafusa/hello-app:1.1

echo

# 新しいReplicaSetが作成されて順次Podが更新されていることを確認
watch kubectl get replicaset 

echo

kubectl delete deployment rolling-update-deployment

