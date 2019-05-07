#!/bin/bash
echo Before

# ラベルappがexampleのPod一覧を表示
kubectl get pods -l app=example

# ラベルappがexampleのPod名を１つ取得する
POD=$(kubectl get pods -l app=example -o jsonpath='{ .items[0].metadata.name }')

echo

# Podを1つ削除する
kubectl delete pod $POD

echo
echo After

# ラベルappがexampleのPod一覧を表示
kubectl get pods -l app=example

