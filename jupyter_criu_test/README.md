# jupyter_criu_test

このプロジェクトは、Jupyter Labコンテナでcriu（Checkpoint/Restore In Userspace）を試すためのサンプルです。

## 必要なもの

- Ubuntu（criuがサポートしているカーネル）
- Podmanのインストール
- criuのインストール（ホスト側）
- sudo権限（チェックポイント/レストアに必要）

## インストール

### Podmanのインストール
```bash
sudo apt update
sudo apt install podman
```

Podmanはrootlessで動作しますが、criuを使用する場合は`--privileged`モードが必要な場合があります。

### criuのインストール

#### Ubuntu（ホスト側）
```bash
sudo apt update
sudo apt install criu
```

### runcランタイムのインストール

Podmanのチェックポイント/レストア機能を使用するには`runc`ランタイムが必要です：

```bash
sudo apt update
sudo apt install runc
```

**注意**: デフォルトの`crun`ランタイムではチェックポイント機能がサポートされていない場合があります。

## 使い方

### 1. スクリプトに実行権限を付与
```bash
chmod +x run.sh
```

### 2. Podmanイメージをビルド
```bash
./run.sh build
```

これにより、Jupyter Labを含むPodmanイメージが作成されます。

### 3. Jupyterコンテナを開始
```bash
./run.sh start
```

これにより、Jupyter Labがコンテナ内で起動します。

Jupyter Labにアクセスするには：
```
http://localhost:8000
```

コンテナのログを確認するには：
```bash
sudo podman logs jupyter_criu_test
```

### 4. チェックポイントを作成
別のターミナルで以下を実行：
```bash
./run.sh checkpoint
```

これにより、実行中のJupyterコンテナの状態がチェックポイントディレクトリに保存されます。

### 5. コンテナをレストア
```bash
./run.sh restore
```

これにより、チェックポイントからJupyterコンテナが復元され、作業状態が続きから再開されます。

レストアされたコンテナのログを確認するには：
```bash
sudo podman logs jupyter_criu_test
```

Jupyter Labにアクセスするには：
```
http://localhost:8000
```

### 6. コンテナを停止
```bash
./run.sh stop
```

### 7. クリーンアップ
```bash
./run.sh clean
```

コンテナとチェックポイントファイルを削除します。

## 注意事項

- コンテナは`--privileged`モードで起動されます（criuに必要）
- criuは特権が必要な場合があります
- すべてのプロセスがチェックポイント可能ではありません
- ネットワーク接続やファイルディスクリプタの状態によっては失敗する場合があります
- Jupyter Labはポート8000で起動します

## トラブルシューティング

### Podmanが見つからない
Podmanがインストールされているか確認：
```bash
which podman
podman --version
```

### criuが見つからない
criuがホスト側にインストールされているか確認：
```bash
which criu
criu --version
```

### チェックポイントに失敗する場合
- コンテナが実行中であることを確認（`sudo podman ps`）
- コンテナのログを確認（`sudo podman logs jupyter_criu_test`）
- チェックポイントディレクトリ内のログファイルを確認
- カーネルがcriuをサポートしているか確認
- コンテナが`--privileged`モードで起動されているか確認

### コンテナが起動しない場合
- Podmanイメージがビルドされているか確認（`sudo podman images`）
- Podmanが正しく設定されているか確認（`sudo podman info`）

### Jupyter Labにアクセスできない場合
- コンテナが実行中であることを確認（`sudo podman ps`）
- ポート8000が使用可能であることを確認
- コンテナのログを確認（`sudo podman logs jupyter_criu_test`）

## 参考資料

- [criu公式サイト](https://criu.org/)
- [criu Wiki](https://criu.org/Main_Page)
- [Jupyter Lab公式サイト](https://jupyter.org/)

