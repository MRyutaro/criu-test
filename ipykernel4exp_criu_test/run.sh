#!/bin/bash
# Jupyterコンテナのcriuチェックポイント/レストアスクリプト

set -e

# タイムスタンプ付きログ
now() { TZ='Asia/Tokyo' date '+%F %T.%3N'; }
log() { echo -e "[$(now)] $*"; }

# ディレクトリの設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKPOINT_DIR="$SCRIPT_DIR/.checkpoint"
CONTAINER_NAME="ipykernel4exp_criu_test"
IMAGE_NAME="localhost/ipykernel4exp_criu_test:latest"
JUPYTER_PORT=8001

# 色付き出力
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log "${BLUE}=== Jupyterコンテナのcriuチェックポイント/レストアスクリプト ===${NC}"

# Podmanがインストールされているか確認
if ! command -v podman &> /dev/null; then
    log "${YELLOW}エラー: Podmanがインストールされていません${NC}"
    echo "インストール方法:"
    echo "  Ubuntu: sudo apt update && sudo apt install podman"
    exit 1
fi

# criuがインストールされているか確認（ホスト側）
if ! command -v criu &> /dev/null; then
    log "${YELLOW}警告: criuがホスト側にインストールされていません${NC}"
    echo "インストール方法:"
    echo "  Ubuntu: sudo apt update && sudo apt install criu"
    exit 1
fi

# runcランタイムがインストールされているか確認（チェックポイント機能に必要）
if ! command -v runc &> /dev/null; then
    log "${YELLOW}警告: runcランタイムがインストールされていません${NC}"
    echo "チェックポイント機能を使用するにはruncランタイムが必要です"
    echo "インストール方法:"
    echo "  Ubuntu: sudo apt update && sudo apt install runc"
    exit 1
fi

# チェックポイントディレクトリの作成
mkdir -p "$CHECKPOINT_DIR"

# チェックポイント処理を関数化
do_checkpoint() {
    # 実行中のコンテナを検出（元のコンテナ名またはバージョン付きコンテナ名）
    CONTAINER_NAME_CHECK=""
    
    # 方法1: 元のコンテナ名が実行中か確認
    if sudo podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        CONTAINER_NAME_CHECK="$CONTAINER_NAME"
    else
        # 方法2: バージョン付きコンテナ名の中で最新のものを検出
        LATEST_VERSION=0
        LATEST_CONTAINER=""
        for container in $(sudo podman ps --format '{{.Names}}' | grep "^${CONTAINER_NAME}_[0-9]\+$"); do
            VERSION=$(echo "$container" | sed "s/^${CONTAINER_NAME}_//")
            if [ "$VERSION" -gt "$LATEST_VERSION" ] 2>/dev/null; then
                LATEST_VERSION=$VERSION
                LATEST_CONTAINER="$container"
            fi
        done
        if [ -n "$LATEST_CONTAINER" ]; then
            CONTAINER_NAME_CHECK="$LATEST_CONTAINER"
        fi
    fi
    
    if [ -z "$CONTAINER_NAME_CHECK" ]; then
        log "エラー: 実行中のコンテナが見つかりません"
        echo "コンテナを起動するには: $0 start"
        echo "または、レストアされたコンテナが実行中であることを確認してください"
        exit 1
    fi
    
    log "${GREEN}チェックポイントを作成します... (コンテナ: $CONTAINER_NAME_CHECK)${NC}"
    log "${YELLOW}注意: チェックポイントにはroot権限が必要です${NC}"
    
    # ディスクバッファをフラッシュして、未書き込みのノート破損を防ぐ
    sudo podman exec "$CONTAINER_NAME_CHECK" sync || true
    sleep 1
    
    # コンテナ名を保存（次回のチェックポイントで使用）
    echo "$CONTAINER_NAME_CHECK" > "$CHECKPOINT_DIR/container_name.txt"
    
    # Podmanの組み込みチェックポイント機能を使用（root権限が必要）
    # --export: チェックポイントをファイルにエクスポート（tar.gz形式）
    # --tcp-established: アクティブなTCP接続を含める（Jupyterなどのネットワーク接続がある場合に必要）
    sudo podman container checkpoint \
        --export "$CHECKPOINT_DIR/checkpoint.tar.gz" \
        --tcp-established \
        "$CONTAINER_NAME_CHECK" || {
        log "チェックポイントの作成に失敗しました"
        exit 1
    }
    
    # ファイルの所有権を現在のユーザーに変更
    sudo chown "$(id -u):$(id -g)" "$CHECKPOINT_DIR/checkpoint.tar.gz"
    
    log "${GREEN}チェックポイントが作成されました！${NC}"
    log "チェックポイントファイル: $CHECKPOINT_DIR/checkpoint.tar.gz"
    log "レストアするには: $0 restore"
}

# レストア処理を関数化
do_restore() {
    if [ ! -f "$CHECKPOINT_DIR/checkpoint.tar.gz" ]; then
        log "エラー: チェックポイントファイルが存在しません。先に '$0 checkpoint' を実行してください"
        exit 1
    fi
    
    log "${GREEN}コンテナをレストアします...${NC}"
    log "${YELLOW}注意: レストアにはroot権限が必要です${NC}"
    
    # バージョン番号を決定（既存のコンテナ名から最大バージョンを取得）
    MAX_VERSION=0
    for container in $(sudo podman ps -a --format '{{.Names}}' | grep "^${CONTAINER_NAME}_[0-9]\+$"); do
        VERSION=$(echo "$container" | sed "s/^${CONTAINER_NAME}_//")
        if [ "$VERSION" -gt "$MAX_VERSION" ] 2>/dev/null; then
            MAX_VERSION=$VERSION
        fi
    done
    NEW_VERSION=$((MAX_VERSION + 1))
    RESTORED_CONTAINER_NAME="${CONTAINER_NAME}_${NEW_VERSION}"
    
    log "${YELLOW}新しいコンテナ名: $RESTORED_CONTAINER_NAME${NC}"
    
    # レストア前のコンテナIDのリストを記録
    CONTAINERS_BEFORE=$(sudo podman ps -a --format '{{.ID}}' | sort)
    
    # 既存のコンテナを削除（元のコンテナ名およびバージョン付きコンテナ名があるとID競合になる）
    if sudo podman ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}(_[0-9]+)?$"; then
        log "${YELLOW}既存の同名プレフィックスのコンテナを停止・削除します...${NC}"
        for cname in $(sudo podman ps -a --format '{{.Names}}' | grep -E "^${CONTAINER_NAME}(_[0-9]+)?$"); do
            echo "$cname"
            sudo podman stop "$cname" 2>/dev/null || true
            sudo podman rm "$cname" 2>/dev/null || true
            sudo podman container cleanup "$cname" 2>/dev/null || true
        done
    fi
    
    # .workspaceディレクトリを作成（存在しない場合）
    WORKSPACE_DIR="$SCRIPT_DIR/.workspace"
    mkdir -p "$WORKSPACE_DIR"
    # jovyanが書き込める権限
    sudo chown -R 1000:100 "$WORKSPACE_DIR" || true
    sudo chmod -R 775 "$WORKSPACE_DIR" || true
    # 必要ディレクトリを用意
    mkdir -p "$WORKSPACE_DIR/.jupyter" "$WORKSPACE_DIR/.jupyter_runtime" "$WORKSPACE_DIR/.jupyter_data" "$WORKSPACE_DIR/.ipython"
    sudo chown -R 1000:100 "$WORKSPACE_DIR/.jupyter" "$WORKSPACE_DIR/.jupyter_runtime" "$WORKSPACE_DIR/.jupyter_data" "$WORKSPACE_DIR/.ipython" || true
    sudo chmod -R 775 "$WORKSPACE_DIR/.jupyter" "$WORKSPACE_DIR/.jupyter_runtime" "$WORKSPACE_DIR/.jupyter_data" "$WORKSPACE_DIR/.ipython" || true
    
    # set -e による途中終了を避けて詳細ログを取得
    set +e
    RESTORED_OUTPUT=$(sudo podman container restore \
        --import "$CHECKPOINT_DIR/checkpoint.tar.gz" \
        --publish "$JUPYTER_PORT:8000" \
        --tcp-established \
        --runtime runc \
        --print-stats \
        2>&1)
    RESTORE_EXIT_CODE=$?
    set -e
    log "restore exit code: $RESTORE_EXIT_CODE"
    log "restore output:\n$RESTORED_OUTPUT"
    
    if [ $RESTORE_EXIT_CODE -ne 0 ]; then
        log "レストアに失敗しました"
        echo "$RESTORED_OUTPUT"
        exit 1
    fi
    
    # 少し待ってからコンテナIDを取得
    sleep 1
    log "containers after restore:"
    sudo podman ps -a --format '{{.ID}}\t{{.Names}}\t{{.Status}}'
    
    # レストアされたコンテナIDを取得
    # 方法1: 出力からコンテナIDを抽出
    RESTORED_ID=$(echo "$RESTORED_OUTPUT" | grep -oE '[a-f0-9]{64}' | head -1)
    
    # 方法2: レストア後に新しく作成されたコンテナを取得
    if [ -z "$RESTORED_ID" ]; then
        CONTAINERS_AFTER=$(sudo podman ps -a --format '{{.ID}}' | sort)
        NEW_CONTAINER=$(comm -13 <(echo "$CONTAINERS_BEFORE") <(echo "$CONTAINERS_AFTER") | head -1)
        if [ -n "$NEW_CONTAINER" ]; then
            RESTORED_ID="$NEW_CONTAINER"
        fi
    fi
    
    # 方法3: 元のコンテナ名で検索（チェックポイントファイルに元の名前が含まれている場合）
    if [ -z "$RESTORED_ID" ]; then
        RESTORED_ID=$(sudo podman ps -a --format '{{.ID}}' --filter "name=$CONTAINER_NAME" | head -1)
    fi
    
    if [ -z "$RESTORED_ID" ]; then
        log "レストアされたコンテナIDを取得できませんでした"
        echo "レストア出力: $RESTORED_OUTPUT"
        echo "現在のコンテナ一覧:"
        sudo podman ps -a --format '{{.ID}}\t{{.Names}}\t{{.Status}}'
        exit 1
    fi
    
    log "取得したコンテナID: $RESTORED_ID"
    
    # コンテナ名を変更（レストア後に名前を変更）
    CURRENT_NAME=$(sudo podman ps -a --format '{{.Names}}' --filter "id=$RESTORED_ID")
    if [ "$CURRENT_NAME" != "$RESTORED_CONTAINER_NAME" ]; then
        sudo podman rename "$RESTORED_ID" "$RESTORED_CONTAINER_NAME" || {
            log "コンテナ名の変更に失敗しました"
            echo "コンテナID: $RESTORED_ID"
            echo "現在のコンテナ名: $CURRENT_NAME"
            echo "期待されるコンテナ名: $RESTORED_CONTAINER_NAME"
            exit 1
        }
        log "コンテナ名を $CURRENT_NAME から $RESTORED_CONTAINER_NAME に変更しました"
    fi
    
    # レストア後のコンテナの状態を確認
    CONTAINER_STATUS=$(sudo podman ps -a --format '{{.Status}}' --filter "id=$RESTORED_ID")
    if echo "$CONTAINER_STATUS" | grep -q "Exited"; then
        log "${YELLOW}警告: レストアされたコンテナが停止しています${NC}"
        log "コンテナのログを確認してください: sudo podman logs $RESTORED_CONTAINER_NAME"
    fi
    
    log "${GREEN}レストアが完了しました！${NC}"
    log "コンテナ名: $RESTORED_CONTAINER_NAME"
    log "Jupyter URL: http://localhost:$JUPYTER_PORT"
    log "ログを確認するには: sudo podman logs $RESTORED_CONTAINER_NAME"
}

# 引数に応じて処理を分岐
case "$1" in
    build)
        log "${GREEN}Podmanイメージをビルドします...${NC}"
        log "${YELLOW}注意: チェックポイント機能を使用するため、rootモードでビルドします${NC}"
        sudo podman build -t "$IMAGE_NAME" "$SCRIPT_DIR" --no-cache
        log "${GREEN}ビルドが完了しました！${NC}"
        ;;
    
    start)
        # 既存のコンテナを停止・削除（rootモードで確認）
        if sudo podman ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            log "${YELLOW}既存のコンテナを停止・削除します...${NC}"
            sudo podman stop "$CONTAINER_NAME" 2>/dev/null || true
            sudo podman rm "$CONTAINER_NAME" 2>/dev/null || true
        fi
        
        log "${GREEN}Jupyterコンテナを起動します...${NC}"
        log "${YELLOW}注意: チェックポイント機能を使用するため、rootモードで起動します${NC}"
        
        # .workspaceディレクトリを作成（存在しない場合）
        WORKSPACE_DIR="$SCRIPT_DIR/.workspace"
        mkdir -p "$WORKSPACE_DIR"
        # Jupyterの実ユーザー(jovyan: 1000:100)が書き込めるように権限調整
        sudo chown -R 1000:100 "$WORKSPACE_DIR" || true
        sudo chmod -R 775 "$WORKSPACE_DIR" || true
        # Jupyterが使用するディレクトリを/app配下に作成
        mkdir -p "$WORKSPACE_DIR/.jupyter" "$WORKSPACE_DIR/.jupyter_runtime" "$WORKSPACE_DIR/.jupyter_data" "$WORKSPACE_DIR/.ipython"
        sudo chown -R 1000:100 "$WORKSPACE_DIR/.jupyter" "$WORKSPACE_DIR/.jupyter_runtime" "$WORKSPACE_DIR/.jupyter_data" "$WORKSPACE_DIR/.ipython" || true
        sudo chmod -R 775 "$WORKSPACE_DIR/.jupyter" "$WORKSPACE_DIR/.jupyter_runtime" "$WORKSPACE_DIR/.jupyter_data" "$WORKSPACE_DIR/.ipython" || true
        
        # privilegedモードで起動（criuのチェックポイント機能に必要）
        # runcランタイムを使用（checkpoint/restoreに必要）
        # ポートマッピングを追加（Jupyter用）
        # .workspaceディレクトリを/appにマウント
        sudo podman run -d \
            --name "$CONTAINER_NAME" \
            --privileged \
            --runtime runc \
            -p "$JUPYTER_PORT:8000" \
            -v "$WORKSPACE_DIR:/app" \
            "$IMAGE_NAME"
        
        CONTAINER_ID=$(sudo podman ps -q -f name="$CONTAINER_NAME")
        log "コンテナID: $CONTAINER_ID"
        echo "$CONTAINER_ID" > "$CHECKPOINT_DIR/container_id.txt"
        echo "$CONTAINER_NAME" > "$CHECKPOINT_DIR/container_name.txt"
        log "${GREEN}Jupyterコンテナが起動しました！${NC}"
        log "コンテナ名: $CONTAINER_NAME"
        log "Jupyter URL: http://localhost:$JUPYTER_PORT"
        log "ログを確認するには: sudo podman logs $CONTAINER_NAME"
        log "チェックポイントを作成するには: $0 checkpoint"
        ;;
    
    checkpoint)
        do_checkpoint
        ;;
    
    restore)
        do_restore
        ;;
    
    restart)
        log "${GREEN}コンテナを再起動します（checkpoint → restore）...${NC}"
        do_checkpoint
        log ""
        do_restore
        ;;
    
    stop)
        log "${YELLOW}コンテナを停止します...${NC}"
        # 元のコンテナ名とバージョン付きコンテナ名の両方を停止
        sudo podman stop "$CONTAINER_NAME" 2>/dev/null || true
        for container in $(sudo podman ps -a --format '{{.Names}}' | grep "^${CONTAINER_NAME}_[0-9]\+$"); do
            sudo podman stop "$container" 2>/dev/null || true
        done
        log "停止完了"
        ;;
    
    clean)
        log "${YELLOW}コンテナとチェックポイントファイルを削除します...${NC}"
        # 元のコンテナ名とバージョン付きコンテナ名の両方を削除
        sudo podman stop "$CONTAINER_NAME" 2>/dev/null || true
        sudo podman rm "$CONTAINER_NAME" 2>/dev/null || true
        for container in $(sudo podman ps -a --format '{{.Names}}' | grep "^${CONTAINER_NAME}_[0-9]\+$"); do
            sudo podman stop "$container" 2>/dev/null || true
            sudo podman rm "$container" 2>/dev/null || true
        done
        rm -rf "$CHECKPOINT_DIR"
        log "クリーンアップ完了"
        ;;
    
    *)
        echo "使用方法: $0 {build|start|checkpoint|restore|restart|stop|clean}"
        echo ""
        echo "コマンド:"
        echo "  build      - Podmanイメージをビルド"
        echo "  start      - Jupyterコンテナを開始"
        echo "  checkpoint - 実行中のコンテナのチェックポイントを作成"
        echo "  restore    - チェックポイントからコンテナをレストア"
        echo "  restart    - チェックポイントを作成してからレストア（再起動）"
        echo "  stop       - コンテナを停止"
        echo "  clean      - コンテナとチェックポイントファイルを削除"
        echo ""
        echo "例:"
        echo "  $0 build      # イメージをビルド"
        echo "  $0 start      # コンテナを開始"
        echo "  $0 checkpoint # チェックポイントを作成"
        echo "  $0 restore    # レストア"
        echo "  $0 restart    # チェックポイント作成→レストア（再起動）"
        exit 1
        ;;
esac
