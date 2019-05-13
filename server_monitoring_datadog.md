# DataDog で Kubernetes のモニタリングをしてみる

## DataDog とは

### DataDog のアカウントを作る
[DataDog公式サイト](https://www.datadoghq.com/)からトライアルアカウントを作成します。  
以下の画面が表示されるので`Kubernetes`を選択して表示されている手順の通りDatadog Agentを作成します。

<img width="1440" alt="スクリーンショット 2019-05-13 13 01 45" src="https://user-images.githubusercontent.com/25437304/57612657-32e3e200-75b0-11e9-9bc3-f27d3215d7e6.png">

```bash
# Datadog AgentがKubernetes監視に必要なロールベースアクセス制御(RBAC)、RBACの権限を設定するServiceAccount、ClusterRoleBindingを作成する
kubectl create -f "https://raw.githubusercontent.com/DataDog/datadog-agent/master/Dockerfiles/manifests/rbac/clusterrole.yaml"
kubectl create -f "https://raw.githubusercontent.com/DataDog/datadog-agent/master/Dockerfiles/manifests/rbac/serviceaccount.yaml"
kubectl create -f "https://raw.githubusercontent.com/DataDog/datadog-agent/master/Dockerfiles/manifests/rbac/clusterrolebinding.yaml"

# Datadog Agentに必要なapi-keyをSecretリソースで作成する
kubectl create secret generic datadog-secret --from-literal api-key="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Datadog Agent(DaemonSet)を作成する
kubectl create -f 
```

Datadog Agentを作成してしばらく待つとアカウント作成を完了できます。  
完了するとDatadogのトップページが表示されます。

<img width="1440" alt="スクリーンショット 2019-05-13 13 12 28" src="https://user-images.githubusercontent.com/25437304/57611520-075ff800-75ae-11e9-83ba-9a390ce16025.png">

