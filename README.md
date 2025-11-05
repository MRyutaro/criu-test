# criu-test

Podmanコンテナでcriu（Checkpoint/Restore In Userspace）を使用して、コンテナのチェックポイントとレストアを試すためのプロジェクトです。

## プロジェクト構成

このプロジェクトには2つのサブプロジェクトが含まれています：

- **criu_test**: シンプルなPythonアプリケーション（カウンター）のチェックポイント/レストア
- **jupyter_criu_test**: Jupyter Labコンテナのチェックポイント/レストア

## 必要な環境

- Ubuntu（criuがサポートしているカーネル）
- Podmanのインストール
- criuのインストール（ホスト側）
- runcランタイムのインストール
- sudo権限（チェックポイント/レストアに必要）

### インストール方法

#### Podman
```bash
sudo apt update
sudo apt install podman
```

#### criu（ホスト側）
```bash
sudo apt update
sudo apt install criu
```

#### runcランタイム
Podmanのチェックポイント/レストア機能を使用するには`runc`ランタイムが必要です：
```bash
sudo apt update
sudo apt install runc
```

**注意**: デフォルトの`crun`ランタイムではチェックポイント機能がサポートされていない場合があります。

## 各サブプロジェクトの使い方

### criu_test

シンプルなPythonカウンターアプリケーションのチェックポイント/レストアを試すサンプルです。

```bash
cd criu_test
chmod +x run.sh

# イメージをビルド
./run.sh build

# コンテナを起動
./run.sh start

# チェックポイントを作成
./run.sh checkpoint

# コンテナをレストア（jupyter_criu_test_1として作成される）
./run.sh restore

# 再度チェックポイント（jupyter_criu_test_1から）
./run.sh checkpoint

# 再度レストア（jupyter_criu_test_2として作成される）
./run.sh restore

# コンテナを停止
./run.sh stop

# クリーンアップ
./run.sh clean
```

詳細は [criu_test/README.md](criu_test/README.md) を参照してください。

### jupyter_criu_test

Jupyter Labコンテナのチェックポイント/レストアを試すサンプルです。

```bash
cd jupyter_criu_test
chmod +x run.sh

# イメージをビルド
./run.sh build

# Jupyterコンテナを起動
./run.sh start

# ブラウザで http://localhost:8000 にアクセス

# チェックポイントを作成
./run.sh checkpoint

# コンテナをレストア（jupyter_criu_test_1として作成される）
./run.sh restore

# 再度チェックポイント（jupyter_criu_test_1から）
./run.sh checkpoint

# 再度レストア（jupyter_criu_test_2として作成される）
./run.sh restore

# コンテナを停止
./run.sh stop

# クリーンアップ
./run.sh clean
```

詳細は [jupyter_criu_test/README.md](jupyter_criu_test/README.md) を参照してください。

## 主な機能

### バージョン管理機能

レストアするたびに、コンテナ名にバージョン番号が自動的に付与されます：
- 1回目のレストア: `コンテナ名_1`
- 2回目のレストア: `コンテナ名_2`
- 3回目のレストア: `コンテナ名_3`
- ...

これにより、複数のチェックポイントからレストアされたコンテナを同時に管理できます。

### 自動コンテナ検出

チェックポイントコマンドは、実行中のコンテナを自動的に検出します：
1. 元のコンテナ名（例: `jupyter_criu_test`）が実行中か確認
2. なければ、バージョン付きコンテナ名（例: `jupyter_criu_test_1`）の中で最新のものを検出

これにより、レストア後にバージョン付きコンテナ名でコンテナが実行されていても、そのコンテナからチェックポイントを取ることができます。

## 注意事項

- **rootモードでの実行**: すべてのコマンドは`sudo podman`を使用するため、rootモードで実行されます。rootモードとrootlessモードではイメージやコンテナの名前空間が分離されているため、`sudo podman images`で確認してください。
- **criuはホスト側のみ**: criuはホスト側にのみインストールが必要です。コンテナ内にcriuをインストールする必要はありません。
- **TCP接続のサポート**: Jupyterなどのネットワーク接続があるコンテナでは、`--tcp-established`オプションが自動的に使用されます。
- **privilegedモード**: コンテナは`--privileged`モードで起動されます（criuに必要）
- **すべてのプロセスがチェックポイント可能ではありません**: 一部のプロセスや状態はチェックポイントできない場合があります

## トラブルシューティング

### イメージが見つからない

rootモードでビルドしたイメージは、rootlessモードからは見えません。確認するには：
```bash
sudo podman images
```

### チェックポイントに失敗する場合

- コンテナが実行中であることを確認（`sudo podman ps`）
- コンテナのログを確認
- チェックポイントディレクトリ内のログファイルを確認
- カーネルがcriuをサポートしているか確認
- コンテナが`--privileged`モードで起動されているか確認

### レストア後にコンテナが停止している場合

レストアされたコンテナがすぐに停止する場合、ログを確認してください：
```bash
sudo podman logs コンテナ名
```

レストア前のチェックポイント作成時点でコンテナが正常に動作していたか確認してください。

## 参考資料

- [criu公式サイト](https://criu.org/)
- [criu Wiki](https://criu.org/Main_Page)
- [Podman公式ドキュメント](https://docs.podman.io/)
