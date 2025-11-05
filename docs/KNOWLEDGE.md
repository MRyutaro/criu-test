jupyterコンテナでcriuを使おうと思ったときには、ここの3つを設定
- JUPYTER_RUNTIME_DIR=/app/.jupyter_runtime
- JUPYTER_DATA_DIR=/app/.jupyter_data
- IPYTHONDIR=/app/.ipython

多分複数のコンテナから1つのマウントができない？
だからリストアする前にもとのコンテナを削除しないといけない？

podmanは通常はroot権限はいらない

ポートNでリッスンしているソケットを含めてチェックポイントを作成するには--tcp-establishedをつける

マウントするときにはホスト側の権限を設定しないといけない  
じゃないとコンテナ側でファイル作成しようとしたときに権限エラーが出る
