# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

PodmanコンテナでCRIU（Checkpoint/Restore In Userspace）を使用して、コンテナのチェックポイントとレストアを試すためのプロジェクトです。3つのサブプロジェクトが含まれています：

- **criu_test**: シンプルなPythonカウンターアプリケーションのチェックポイント/レストア
- **jupyter_criu_test**: Jupyter Labコンテナのチェックポイント/レストア
- **ipykernel4exp_criu_test**: カスタムIPythonカーネルを使用したJupyterコンテナのチェックポイント/レストア

## 開発環境要件

- Ubuntu（criuがサポートしているカーネル）
- Podmanのインストール（`sudo apt install podman`）
- criuのインストール（ホスト側のみ、`sudo apt install criu`）
- runcランタイム（`sudo apt install runc`）- デフォルトの`crun`ではチェックポイント機能がサポートされていない場合がある
- sudo権限（チェックポイント/レストアに必要）

## 重要な実行モードの理解

### rootモードとrootlessモード

このプロジェクトのすべてのPodmanコマンドは**rootモード**（`sudo podman`）で実行されます。これは、criuのチェックポイント/レストア機能に必要な特権が必要なためです。

**重要**: rootモードとrootlessモードではイメージやコンテナの名前空間が分離されているため：
- イメージを確認する際は `sudo podman images` を使用
- コンテナを確認する際は `sudo podman ps` または `sudo podman ps -a` を使用

## 各サブプロジェクトの使い方

各サブプロジェクトには `run.sh` スクリプトがあり、以下のコマンドをサポートしています：

```bash
./run.sh build       # Podmanイメージをビルド
./run.sh start       # コンテナを起動
./run.sh checkpoint  # 実行中のコンテナのチェックポイントを作成
./run.sh restore     # チェックポイントからコンテナをレストア
./run.sh stop        # コンテナを停止
./run.sh clean       # コンテナとチェックポイントファイルを削除
```

**ipykernel4exp_criu_test のみ**、追加で `restart` コマンド（`checkpoint` → `restore`）をサポート：
```bash
./run.sh restart     # チェックポイント作成→レストア（再起動）
```

### サブプロジェクト別の詳細

#### criu_test
- **ポート**: なし
- **用途**: シンプルなカウンターアプリケーションでCRIUの基本動作を確認
- **ログ確認**: `sudo podman logs criu_test`

#### jupyter_criu_test
- **ポート**: 8000 (http://localhost:8000)
- **用途**: Jupyter Labのチェックポイント/レストア
- **ログ確認**: `sudo podman logs jupyter_criu_test`

#### ipykernel4exp_criu_test
- **ポート**: 8001 (http://localhost:8001)
- **用途**: カスタムIPythonカーネルを使用したJupyterのチェックポイント/レストア
- **ログ確認**: `sudo podman logs ipykernel4exp_criu_test`

## アーキテクチャの重要なポイント

### 1. バージョン管理システム

レストアするたびに、コンテナ名にバージョン番号が自動的に付与されます：
- 1回目のレストア: `コンテナ名_1`
- 2回目のレストア: `コンテナ名_2`
- 3回目のレストア: `コンテナ名_3`

これにより、複数のチェックポイントからレストアされたコンテナを同時に管理できます。

### 2. 自動コンテナ検出

`./run.sh checkpoint` コマンドは、実行中のコンテナを以下の順序で自動検出します：
1. 元のコンテナ名（例: `jupyter_criu_test`）が実行中か確認
2. なければ、バージョン付きコンテナ名（例: `jupyter_criu_test_1`, `jupyter_criu_test_2`）の中で最新のものを検出

### 3. コンテナの実行要件

すべてのコンテナは以下の設定で起動されます：
- `--privileged`: criuのチェックポイント機能に必要
- `--runtime runc`: checkpoint/restore機能に必要
- `-v $WORKSPACE_DIR:/app`: ホスト側のワークスペースディレクトリをマウント

### 4. Jupyterコンテナ特有の設定

Jupyterコンテナ（jupyter_criu_test、ipykernel4exp_criu_test）では、チェックポイント/レストアを可能にするために、以下の環境変数を設定：
- `JUPYTER_RUNTIME_DIR=/app/.jupyter_runtime`
- `JUPYTER_DATA_DIR=/app/.jupyter_data`
- `IPYTHONDIR=/app/.ipython`

これらは、複数のコンテナから同一のボリュームマウントができないため、コンテナ固有のパスに設定する必要があります。

### 5. チェックポイント/レストアのオプション

- `--tcp-established`: アクティブなTCP接続を含める（Jupyterなどのネットワーク接続がある場合に必要）
- `--file-locks`: ファイルロックをダンプする（CRIUのエラー回避のため、ipykernel4exp_criu_testで使用）
- `--export`: チェックポイントをtar.gz形式でエクスポート
- `--import`: tar.gz形式のチェックポイントをインポート

### 6. ワークスペースディレクトリの権限

Jupyterコンテナでは、ユーザー `jovyan` (UID: 1000, GID: 100) が書き込めるように、`.workspace` ディレクトリの権限を設定：
```bash
sudo chown -R 1000:100 "$WORKSPACE_DIR"
sudo chmod -R 775 "$WORKSPACE_DIR"
```

## トラブルシューティング

### イメージが見つからない場合

rootモードでビルドしたイメージは、rootlessモードからは見えません。確認するには：
```bash
sudo podman images
```

### チェックポイントに失敗する場合

- コンテナが実行中であることを確認（`sudo podman ps`）
- コンテナのログを確認（`sudo podman logs <コンテナ名>`）
- チェックポイントディレクトリ内のログファイルを確認
- カーネルがcriuをサポートしているか確認
- コンテナが`--privileged`モードで起動されているか確認

### レストア後にコンテナが停止している場合

レストアされたコンテナがすぐに停止する場合、ログを確認：
```bash
sudo podman logs <コンテナ名>
```

レストア前のチェックポイント作成時点でコンテナが正常に動作していたか確認してください。

## その他の注意点

- criuはホスト側にのみインストールが必要です。コンテナ内にcriuをインストールする必要はありません。
- すべてのプロセスがチェックポイント可能ではありません。一部のプロセスや状態はチェックポイントできない場合があります。
