# k8s ハンズオン手順書

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

```
az group create --name decode2019-cd65-71 --location japaneast
```

リソースグループ上に Kubernetes クラスターを作成する

```bash
az aks create --resource-group decode2019-cd65-71 --name k8s-handson --node-count 1 --generate-ssh-keys
```
作成にはしばらく時間がかかる。以下のコマンドでステータスが`Succeeded`になるまで待つ (Ctrl+Cで終了)
```
watch "az aks show -g decode2019-cd65-71 -n k8s-handson | grep provisioningState"
```

Kubernetes クラスターに接続するための認証情報を取得する

```bash
az aks get-credentials --name k8s-handson --resource-group decode2019-cd65-71
```

## Pod を作成してみる

Pod は Kubernetes における最小単位の環境です。  
Pod は 1 つ以上のコンテナを動かす環境で、複数のコンテナを動かす場合同じ Pod 内であれば コンテナはlocalhost で互いに通信することができます。  
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
  - name: nginx-container
    # コンテナイメージを指定
    image: nginx:1.12
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

STATUS が Running になったら起動成功  

## ReplicaSet を作成してみる

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
    # labelに一致するPodでレプリカを組む
      matchLabels:
        app: example
  template:
    # template以下がPodとほとんど同じ
    metadata:
      labels:
        app: example
    spec:
      containers:
      - name: nginx-container
        image: nginx:1.12
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
Podそれぞれがハッシュ付きの名前で異なるIPアドレスで起動されている
```bash
kubectl get pods -o wide
```
### ReplicaSetのセルフヒーリングを試してみる
ReplicaSetを組んでいればPodに障害が起きて停止しても、すぐにPodが再作成されていることがわかる。  
以下のシェルスクリプトを実行すると、Podの削除前と削除後でPodの数が変わっていないことがわかる。
```
./self-healing-demo.sh
```

## Deployment を作成してみる
DeploymentはReplicaSetをスケーラブルに扱うためのリソース。  

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
    app: example
  template:
    metadata:
      labels:
        app: example
    spec:
      containers:
      - name: nginx-container
        image: nginx:1.12
    
```

</details>

Deploymentはアプリケーションを更新するときに、後述のローリングアップデートやオートスケーリングなどのデプロイに関する設定を記述することができる。  
よって、DeploymentのマニフェストはReplicaSetやPodのマニフェストを上記のように個別に書くということは基本的にはありません。

### Deploymentのローリングアップデートを試してみる
Deploymentでは基本的にローリングアップデートでアプリケーションが順次更新されるため、ダウンタイムなしにアプリケーションを更新することができます。
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
    app: example
  template:
    metadata:
      labels:
        app: example
    spec:
      containers:
      - name: nginx-container
        image: nginx:1.12
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
kubectl set image deployment rolling-update-deployment nginx-container=nginx:1.13
# 新しいReplicaSetが作成されて順次Podが更新されていることを確認
watch kubectl get replicaset 
```

### Podのオートスケーリングを有効にしてみる
レプリカの数は手動で変更することもできますが、以下のようにマニフェストを設定することでPodの負荷状況に応じて自動でスケールアウトすることができます。

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
      app: example
  template:
    metadata:
      labels:
        app: example
    spec:
      containers:
      - name: nginx-container
        image: nginx:1.12

```
</details>

## Service を作成してみる
Kubernetes上のアプリケーションを外部に公開するにはService (もしくはIngress) というリソースを使います。  
以下は負荷分散のためのシンプルなロードバランサーのServiceの例です。

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
    # 8080番ポートに受けて各Podの80番ポートに転送する
    port: 8080
    targetPort: 80
  selector:
  # Deploymentと同じラベルをつける
    app: example
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
      app: example
  template:
    metadata:
      labels:
        app: example
    spec:
      containers:
      - name: nginx-container
        image: nginx:1.12
        # コンテナのポートを指定
        ports:
        - containerPort: 80
```

</details>

適用
```bash
kubeclt apply -f service-example.yaml
```
ServiceのEXTERNAL-IPが<Pendding>から特定のIPアドレスになるまで待ちます(`Ctrl + C`で終了)
```bash
kubeclt get services --watch
```
EXTERNAL-IPが実IPになったら、ブラウザでアクセスしてみましょう。(`http://<EXTERNAL-IP>:8080`でアクセスできます。)

## 後片付け
従量課金の場合、ノードが起動している間はお金がかかり続けます。  
以下のコマンドを実行してこのハンズオンのリソースグループごと消してしまいましょう。
```bash
az group delete --name decode2019-cd65-71 --yes --no-wait
```
