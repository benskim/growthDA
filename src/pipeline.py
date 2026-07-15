# import duckdb

# # 1. DB 연결 (없으면 새로 생성됨)
# conn = duckdb.connect('analytics.db')

# # 2. SQL 파일 읽기

# with open('src/sql/01_session.sql', 'r', encoding='utf-8') as f:
#     sql_script = f.read()

# # 3. SQL 실행
# conn.execute(sql_script)

# # 4. 연결 종료
# conn.close()



import os
import glob
import duckdb

# 1. SQL 파일들이 위치한 디렉토리 설정
sql_dir = '/workspaces/growthDA/src/sql'
# 🎯 '02'로 시작하는 .sql 파일만 가져와 정렬합니다.
sql_files = sorted(glob.glob(os.path.join(sql_dir, '02*.sql')))

if not sql_files:
    print(f"❌ '{sql_dir}' 폴더에 '02'로 시작하는 .sql 파일이 없습니다.")
    exit()

# 2. DuckDB 데이터베이스 연결
db_path = '/workspaces/growthDA/analytics.db'
conn = duckdb.connect(db_path)

print(f"🔄 DuckDB 연결 성공 ({db_path})")
print(f"📂 총 {len(sql_files)}개의 '02' 계열 파일을 실행합니다.\n" + "-"*40)

try:
    # 3. 필터링된 SQL 파일을 순서대로 읽어서 실행
    for file_path in sql_files:
        file_name = os.path.basename(file_path)
        print(f"🚀 실행 중: {file_name} ...", end="", flush=True)
        
        with open(file_path, 'r', encoding='utf-8') as f:
            sql_script = f.read()
            
        # SQL 스크립트 실행
        conn.execute(sql_script)
        print(" [완료]")

    print("-"*40 + "\n✅ 지정된 SQL 파일이 모두 성공적으로 실행되었습니다.")

except Exception as e:
    print(f"\n❌ 실행 중 오류 발생: {e}")

finally:
    # 4. 연결 종료 (잠금 해제)
    conn.close()
    print("🔒 DuckDB 연결이 닫혔습니다.")
