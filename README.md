# Kubernetes ハンズオン手順書

Kubernetes とはどのようなものかステップバイステップで実際に手を動かしながら見ていきます。  
このハンズオンでは Kubernetes の最小単位である Pod から見ていき、最終的に Deployment と LoadBalancer Service を使ったアプリケーションのデプロイを体験します。  
また、Kubernetes クラスター上のノードを起動している間お金がかかり続けますので、**最後の「後片付け」のステップは必ず実行してください。**

## ハンズオンを進めるための準備

- ブラウザから手順書(このリポジトリ)を開く  
  https://git.io/fjCRU
- Azure ポータルを開く  
  https://portal.azure.com/
- Azure Cloud Shell を開く(Bash を選択)
- Azure Cloud Shell でサンプルリポジトリをクローンする

```bash
git clone https://github.com/softoika/decode2019-k8s-handson
```

サンプルリポジトリへ移動

```bash
cd decode2019-k8s-handson
```

リソースグループを作成する

```bash
az group create --name decode2019-cd65-71 --location japaneast
```

リソースグループ上に Kubernetes クラスターを作成する

```bash
az aks create --resource-group decode2019-cd65-71 --name k8s-handson --node-count 1 --generate-ssh-keys
```

作成にはしばらく時間がかかる。以下のコマンドでステータスが`Succeeded`になるまで待つ (Ctrl+C で終了)

```
watch "az aks show -g decode2019-cd65-71 -n k8s-handson | grep provisioningState"
```

Kubernetes クラスターに接続するための認証情報を取得する

```bash
az aks get-credentials --name k8s-handson --resource-group decode2019-cd65-71
```

## Pod を作成してみる
<img width="695" alt="スクリーンショット 2019-05-30 10 44 54" src="https://user-images.githubusercontent.com/25437304/58602484-1f32be00-82c8-11e9-8b7b-725bcd4cced5.png">

Pod は Kubernetes における最小単位の環境です。  
Pod は 1 つ以上のコンテナを動かす環境で、複数のコンテナを動かす場合同じ Pod 内であれば コンテナは localhost で互いに通信することができます。  
Pod のマニフェストファイルの単純な例は以下の通りです。

<details>
<summary><b>pod-example.yaml</b></summary>

```yaml
# /api/v1/namespaces/{namespace}/pods にリクエストを投げる
apiVersion: v1
kind: Pod
metadata:
  name: pod-example
spec:
  containers:
    - name: hello-app-container
      # コンテナイメージを指定
      image: rhanafusa/hello-app:1.0
```

</details>

マニフェストファイルの適用は`kubectl apply`コマンドを使います。

```bash
kubectl apply -f pod-example.yaml
```

また、`kubectl get`コマンドで Pod の起動状態を確認できます。

```bash
kubectl get pods
```

<img width="424" alt="kubectl_get_pods" src="https://user-images.githubusercontent.com/25437304/57520904-d091a400-7359-11e9-81f4-98d1413a0e8c.png">

STATUS が Running になったら起動成功

### (おまけ) その他よく使うコマンド
```bash
# yamlに何を記述できるかコマンドで確認する
kubectl explain pod
kubectl explain pod.spec
kubectl explain pod.spec.containers.ports
# podの詳細や起動履歴を確認する
kubectl describe pods
# アプリケーションのログを確認する
kubectl logs pod-example
# podの中に入る(pod内で有効なコマンドを実行する)
kubectl exec -it pod-example -- bash
kubectl exec -it pod-example -- uname -a
```
その他コマンドの詳細を知りたければ`kubectl -h`または`kubectl サブコマンド -h`でみれます。  
また、公式でコマンドの[リファレンス](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands)が公開されています。

## ReplicaSet を作成してみる
<img width="732" alt="スクリーンショット 2019-05-30 10 45 03" src="https://user-images.githubusercontent.com/25437304/58602503-2fe33400-82c8-11e9-8d90-8274f923155b.png">


ReplicaSet はその名の通り、Pod のレプリケーションを組んで可用性を高めることができます。  
以下は 3 つのレプリカで構成された ReplicaSet の例です。

<details>
<summary><b>replicaset-example.yaml</b></summary>

```yaml
# /apis/apps/v1/namespaces/{namespace}/replicasets にリクエストを投げる
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: replicaset-example
spec:
  replicas: 3
  selector:
    # labelの検索条件
    matchLabels:
      app: hello-app
  template:
    # template以下がPodとほとんど同じ
    metadata:
      labels:
        app: hello-app
    spec:
      containers:
        - name: hello-app-container
          image: rhanafusa/hello-app:1.0
```

</details>
  
適用
```bash
kubectl apply -f replicaset-example.yaml
```
レプリカ数3台でReplicaSetが起動されていることを確認
```bash
kubectl get replicaset -o wide
```

<img width="1115" alt="スクリーンショット 2019-05-13 18 59 49" src="https://user-images.githubusercontent.com/25437304/57613233-565b5c80-75b1-11e9-944e-e7a8fe1770a4.png">


Pod それぞれがハッシュ付きの名前で異なる IP アドレスで起動されている

```bash
kubectl get pods -o wide
```

<img width="851" alt="kubectl_get_pods_-o_wide" src="https://user-images.githubusercontent.com/25437304/57520993-09ca1400-735a-11e9-9eb5-eb1563daa5b4.png">

### ReplicaSet のセルフヒーリングを試してみる

ReplicaSet を組んでいれば Pod に障害が起きて停止しても、すぐに Pod が再作成されていることがわかる。  
以下のシェルスクリプトを実行すると、Pod の削除前と削除後で Pod の数が変わっていないことがわかる。

```
./self-healing-demo.sh
```

<img width="473" alt="self-healing-demo sh" src="https://user-images.githubusercontent.com/25437304/57521023-1d757a80-735a-11e9-9310-820067c34265.png">

## Deployment を作成してみる
<img width="723" alt="スクリーンショット 2019-05-30 10 45 13" src="https://user-images.githubusercontent.com/25437304/58602517-3d002300-82c8-11e9-94b4-d58c7e06fb91.png">

Deployment は ReplicaSet をスケーラブルに扱うためのリソース。

<details>
<summary><b>simple-deployment.yaml</b></summary>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: simple-deployment
spec:
  replicas: 3
  selector:
  matchLabels:
    app: hello-app
  template:
    metadata:
      labels:
        app: hello-app
    spec:
      containers:
        - name: hello-app-container
          image: rhanafusa/hello-app:1.0
```

</details>

Deployment はアプリケーションを更新するときに、後述のローリングアップデートやオートスケーリングなどのデプロイに関する設定を記述することができる。  
よって、**基本的には Pod や ReplicaSet は Deployment を通して定義すればよいです(Deployment のマニフェストファイルだけ作れば OK)。**

### Deployment のローリングアップデートを試してみる

Deployment では基本的にローリングアップデートでアプリケーションが順次更新されるため、ダウンタイムなしにアプリケーションを更新することができます。
ローリングアップデートのデモ用マニフェストは以下の通りです。

<details>
<summary><b>rolling-update-deployment.yaml</b></summary>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rolling-update-deployment
spec:
  ## ローリングアップデートの設定 ##
  # 新規作成されたPodがReadyになってから起動成功と判断するまでの猶予時間
  minReadySeconds: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      # 1台ずつ更新していく
      maxSurge: 1
      maxUnavailable: 0
  ##############################
  replicas: 3
  selector:
  matchLabels:
    app: hello-app
  template:
    metadata:
      labels:
        app: hello-app
    spec:
      containers:
        - name: hello-app-container
          image: rhanafusa/hello-app:1.0
```

</details>

それではローリングアップデートを体験してみましょう。  
以下のシェルスクリプトを実行してローリングアップデートされていく様子を確認することができます。

```bash
./rolling-update-demo.sh
```

`Ctrl + C`でスクリプトを終了できます。  
シェルスクリプトの内容を一部抜粋すると以下のようになっています。

```bash
# Deploymentを作成
kubectl apply -f rolling-update-deployment.yaml
# コンテナイメージを変更
kubectl set image deployment rolling-update-deployment hello-app-container=rhanafusa/hello-app:1.1

# 新しいReplicaSetが作成されて順次Podが更新されていることを確認
watch kubectl get replicaset
```

### Pod のオートスケーリングを有効にしてみる

レプリカの数は手動で変更することもできますが、以下のようにマニフェストを設定することで Pod の負荷状況に応じて自動でスケールアウトすることができます。

<details>
<summary><b>autoscale-example.yaml</b></summary>

```yaml
## HorizontalAutoscalerの設定
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: autoscale-example
spec:
  # レプリカ数の下限
  minReplicas: 2
  # レプリカ数の上限
  maxReplicas: 5
  # PodのCPUが70%になるように調節する
  targetCPUUtilizationPercentage: 70
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: autoscalable-deployment
---
## 対象のDeploymentの設定
apiVersion: apps/v1
kind: Deployment
metadata:
  name: autoscalable-deployment
spec:
  selector:
    matchLabels:
      app: hello-app
  template:
    metadata:
      labels:
        app: hello-app
    spec:
      containers:
        - name: hello-app-container
          image: rhanafusa/hello-app:1.0
```

</details>

## Service を作成してみる
<img width="778" alt="スクリーンショット 2019-05-30 10 45 30" src="https://user-images.githubusercontent.com/25437304/58602547-51dcb680-82c8-11e9-9361-26c452084add.png">

Kubernetes 上のアプリケーションを外部に公開するには Service (もしくは Ingress) というリソースを使います。  
以下は負荷分散のためのシンプルなロードバランサーの Service の例です。

<details>
<summary><b>service-example.yaml</b></summary>

```yaml
## シンプルなServiceの定義
apiVersion: v1
kind: Service
metadata:
  name: service-example
spec:
  type: LoadBalancer
  ports:
    - protocol: "TCP"
      # 8080番ポートに受けて各Podの8080番ポートに転送する
      port: 8080
      targetPort: 8080
  selector:
    # Deploymentと同じラベルをつける
    app: hello-app
---
## Serviceに対応したDeploymentを定義
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-example-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hello-app
  template:
    metadata:
      labels:
        app: hello-app
    spec:
      containers:
        - name: hello-app-container
          image: rhanafusa/hello-app:1.0
          # コンテナのポートを指定
          ports:
            - containerPort: 8080
```

</details>

適用

```bash
kubectl apply -f service-example.yaml
```

Service の EXTERNAL-IP が<Pendding>から特定の IP アドレスになるまで待ちます(`Ctrl + C`で終了)

```bash
kubectl get services --watch
```

<img width="528" alt="kubectl_get_services_--watch" src="https://user-images.githubusercontent.com/25437304/57521051-33833b00-735a-11e9-862e-5d9e82168638.png">

EXTERNAL-IP が実 IP になったら、ブラウザでアクセスしてみましょう。(`http://<EXTERNAL-IP>:8080/greeting`でアクセスできます。)

## 後片付け

従量課金の場合、ノードが起動している間はお金がかかり続けます。  
以下のコマンドを実行して(もしくは Azure Portal の画面上から)、このハンズオンのリソースグループごと消してしまいましょう。

```bash
az group delete --name decode2019-cd65-71 --yes --no-wait
```

今回 Azure Cloud Shell を初めて使った場合 Cloud Shell 用のストレージとリソースグループも作成されています。  
僅かではありますが、起動している間お金がかかります。  
こちらも普段使っていないのであれば削除しておきましょう。

```bash
az group delete --name cloud-shell-storage-southeastasia --yes --no-wait
```
