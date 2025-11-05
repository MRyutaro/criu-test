#!/usr/bin/env python3
"""
criuの基本的なテストスクリプト
簡単なカウンターを実行し、チェックポイント/レストアをテストします
"""

import time
import sys
import os


def main():
    """メイン関数 - カウンターを表示し続ける"""
    counter = 0
    pid = os.getpid()
    
    print(f"プロセスID: {pid}")
    print("カウンターを開始します...")
    print("Ctrl+Cで停止、またはcriuでチェックポイントしてください")
    
    try:
        while True:
            counter += 1
            print(f"カウンター: {counter}")
            time.sleep(2)
    except KeyboardInterrupt:
        print(f"\n停止しました。最終カウント: {counter}")
        sys.exit(0)

if __name__ == "__main__":
    main()
