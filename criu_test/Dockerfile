FROM python:3.11-slim

WORKDIR /app

# アプリケーションファイルをコピー
COPY main.py /app/

# スクリプトに実行権限を付与
RUN chmod +x /app/main.py

# 環境変数を設定（出力のバッファリングを無効化）
ENV PYTHONUNBUFFERED=1

# エントリーポイント
CMD ["python3", "/app/main.py"]
