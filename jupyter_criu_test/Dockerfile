FROM quay.io/jupyter/scipy-notebook:latest

# 作業ディレクトリを設定
WORKDIR /app

# 環境変数を設定（出力のバッファリングを無効化）
ENV PYTHONUNBUFFERED=1

# Jupyter Labを起動
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8000", "--no-browser", "--allow-root", "--NotebookApp.token=''", "--NotebookApp.password=''"]

