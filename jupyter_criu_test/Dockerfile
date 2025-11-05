FROM quay.io/jupyter/scipy-notebook:latest

# 作業ディレクトリを設定
WORKDIR /app

# 環境変数を設定（出力のバッファリングを無効化）
ENV PYTHONUNBUFFERED=1 \
    JUPYTER_RUNTIME_DIR=/app/.jupyter_runtime \
    JUPYTER_DATA_DIR=/app/.jupyter_data \
    IPYTHONDIR=/app/.ipython

# Jupyter Labを起動（署名DBを/app配下に移動）
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8000", "--no-browser", "--allow-root", "--NotebookApp.token=''", "--NotebookApp.password=''", "--NotebookNotary.db_file=/app/.jupyter/nbsignatures.db"]

