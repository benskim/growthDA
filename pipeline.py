

import duckdb
import os
# 1. 저장할 폴더 및 영구 DB 파일 연결
db_path = "analytics.db"
conn = duckdb.connect(db_path)
# 2. Codespaces 사양에 맞춘 성능 최적화 설정# (메모리가 부족하면 자동으로 SSD를 활용하도록 임시 디렉토리 지정)
os.makedirs("tmp", exist_ok=True)
conn.execute("SET memory_limit = '14GB';")  # 보유 RAM의 70~80% 할당
conn.execute("SET threads = 4;")            # CPU 코어 수에 맞게 설정
conn.execute("PRAGMA temp_directory='tmp';")

print("2개의 CSV 파일 스캔 및 event_time 정렬 저장 시작...")
# 3. [핵심] 와일드카드로 2개 파일을 동시에 읽고, event_time 순서로 정렬하여 테이블 생성# 만약 파일명이 다르면 ['file1.csv', 'file2.csv'] 형태로 넣어도 됩니다.
conn.execute("""
    CREATE TABLE IF NOT EXISTS integrated_events AS 
    SELECT * FROM read_csv_auto('sample*.csv') 
    ORDER BY event_time;  -- ★ 이 정렬이 Spark급 속도를 내는 치트키입니다.""")
# 4. 블록 스킵(Zone Map) 활성화를 위한 데이터 통계 정보 업데이트
print("인덱스 및 통계 정보 최적화 중...")
conn.execute("ANALYZE integrated_events;")
conn.close()

print(f"성공적으로 변환되었습니다! 생성된 {db_path} 파일 용량을 확인해보세요.")