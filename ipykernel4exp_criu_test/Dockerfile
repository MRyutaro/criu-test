FROM python:3.12-slim

WORKDIR /tmp

# システムライブラリをインストール
RUN apt-get update && apt-get install -y \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# uvのセットアップ
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# 必要なソースコードをコピー
COPY ipykernel4exp/ ./ipykernel4exp/
COPY pyproject.toml ./
COPY uv.lock ./

# 依存関係をインストール
RUN uv sync --frozen --no-editable && \
    uv run ipykernel4exp install && \
    uv run jupyter kernelspec list && \
    /tmp/.venv/bin/python -m ensurepip

# 作業ディレクトリを設定
WORKDIR /app

# 環境変数を設定（出力のバッファリングを無効化）
ENV PYTHONUNBUFFERED=1 \
    JUPYTER_RUNTIME_DIR=/app/.jupyter_runtime \
    JUPYTER_DATA_DIR=/app/.jupyter_data \
    IPYTHONDIR=/app/.ipython \
    PATH="/tmp/.venv/bin:$PATH"

# Jupyter Labを起動（署名DBを/app配下に移動）
CMD ["uv", "run", "jupyter", "lab", "--ip=0.0.0.0", "--port=8000", "--no-browser", "--allow-root", "--NotebookApp.token=''", "--NotebookApp.password=''", "--NotebookNotary.db_file=/app/.jupyter/nbsignatures.db"]
