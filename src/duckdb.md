# duckdb 환경설정/설치
실무에서는 파이썬 코드로 데이터 파이프라인(ETL)을 짜면서, 동시에 터미널(CLI)을 열어 데이터가 잘 들어갔는지 SQL로 수시로 조회(Ad-hoc 쿼리)하기 때문입니다.
GitHub Codespaces에서 이 실무 환경을 가장 완벽하게 세팅하는 3단계 방법을 알려드립니다.
------------------------------
## 1단계: Codespaces에 필수 확장 프로그램(Extensions) 설치
VS Code 환경인 Codespaces 좌측의 Extensions(확장 기능) 탭(Ctrl+Shift+X)에서 아래 2개를 검색해 설치하세요.

   1. Python (Microsoft 제공): 파이썬 코드 실행 및 디버깅 필수
   2. Jupyter (Microsoft 제공): 데이터 분석가들이 실무에서 데이터 시각화 및 검증용으로 가장 많이 쓰는 노트북 환경

------------------------------
## 2단계: 실무형 통합 설치 및 데이터 베이스 파일 생성
터미널을 열고 파이썬 패키지와 CLI를 동시에 사용할 수 있도록 설치합니다.

### 1. Python 패키지 설치
pip install duckdb pandas
### 2. CLI 도구 설치 (터미널용)
curl https://install.duckdb.org | sh
duckdb analytics.db

### 3. duckdb sql 
-- 보유 RAM 사양에 맞춰 설정 (Codespaces 기본형이면 6GB~12GB 권장, 여기선 12GB 지정)
SET memory_limit = '12GB';
-- CPU 스레드 수 최적화
SET threads = 4;
-- 대용량 연산 중 메모리가 부족할 때 사용할 임시 폴더 생성
PRAGMA temp_directory='tmp';

------------------------------
## 4단계: [핵심] 2개 CSV 동시 로드 및 event_time 정렬 저장 (SQL)
이제 하나의 SQL 문으로 2개의 CSV 파일을 병렬로 읽어 들이면서, event_time 기준으로 정렬된 고속 분석용 테이블을 생성합니다.
현재 다루고 계신 두 CSV 파일의 실제 파일명 구조에 맞게 아래 3가지 보기 중 하나를 골라 그대로 붙여넣으세요.

* 보기 A: 파일명이 data_1.csv, data_2.csv 처럼 일관된 경우 (와일드카드)

CREATE TABLE events AS SELECT * FROM read_csv_auto('data/sample*.csv') ORDER BY event_time;

* 보기 B: 파일명이 완전히 다른 경우 (리스트 형식)

CREATE TABLE events AS SELECT * FROM read_csv_auto(['first_file.csv', 'second_file.csv']) ORDER BY event_time;

* 보기 C: 파일들이 특정 폴더(예: raw_data) 안에 모여있는 경우

CREATE TABLE events AS SELECT * FROM read_csv_auto('raw_data/*.csv') ORDER BY event_time;


💡 주의 및 팁: 19GB 텍스트 데이터를 통째로 압축·정렬하는 과정이므로 사양에 따라 수 분 정도 시간이 소요됩니다. 터미널이 멈춘 것처럼 보여도 백그라운드에서 열심히 연산 중이니 잠시 기다려 주세요. 완료되면 다시 D 프롬프트가 떨어집니다.

------------------------------
## 5단계: 블록 스킵 통계 정보 갱신 및 완료
데이터 적재가 끝나면 DuckDB가 데이터 블록들의 경계선(Zone Map)을 정확히 인지할 수 있도록 다음 명령어를 날려줍니다.

ANALYZE events;

------------------------------
## 6단계: 속도 검증 (Spark급 속도 체감하기)
모든 준비가 끝났습니다. 잘 저장되었는지, 속도가 진짜 잘 나오는지 특정 날짜 조건을 넣어서 테스트해 보세요.

-- 전체 데이터 행 개수 확인SELECT COUNT(*) FROM events;
-- 특정 시간대 조회 속도 테스트 (0.1초 내외로 결과가 튀어나옵니다)
SELECT COUNT(*), AVG(price) FROM events WHERE event_time >= '2026-07-01 00:00:00' 
  AND event_time < '2026-07-02 00:00:00';

테스트가 끝나면 .exit를 입력하여 DuckDB를 종료할 수 있습니다. 종료 후 Codespaces 파일 탐색기나 터미널(ls -lh)을 통해 analytics.db 파일의 용량을 확인해 보세요. 원래 19GB였던 데이터가 몇 GB 수준으로 줄어든 것을 확인할 수 있습니다.
혹시 3단계에서 CSV 파일을 읽을 때 "Mismatch"나 "Invalid Type" 같은 데이터 타입 파싱 에러가 발생하나요? 아니면 정상적으로 테이블이 만들어졌나요? 오류가 있다면 해당 에러 메시지를 알려주세요!



---



# 대규모 데이터셋 가져오는 법

파일의 크기는 19GB가 되지 않으며, 약 2GB~4GB 수준으로 대폭 압축됩니다.
DuckDB는 두 파일을 메모리 안에서 거대한 하나의 스트림으로 합친 뒤, 열(Column) 단위로 강력하게 압축하여 디스크에 저장하기 때문입니다. 용량이 80% 이상 줄어들기 때문에 디스크에서 읽어오는 속도 자체가 빨라져 Spark와 대등하거나 더 빠른 속도가 나옵니다.

------------------------------
## 1. 2개 파일 한 번에 읽어 정렬 저장하는 마스터 코드 (Python)
실무에서 여러 CSV 파일을 다룰 때는 파일명을 하나씩 지정하기보다 와일드카드(*)나 리스트를 사용합니다. 예를 들어 파일명이 data_part1.csv, data_part2.csv 라면 data_part*.csv 형태로 한 번에 묶어서 읽을 수 있습니다.

```python

import duckdb
import os
# 1. 저장할 폴더 및 영구 DB 파일 연결
db_path = "merged_analytics.db"
conn = duckdb.connect(db_path)
# 2. Codespaces 사양에 맞춘 성능 최적화 설정# (메모리가 부족하면 자동으로 SSD를 활용하도록 임시 디렉토리 지정)
os.makedirs("tmp", exist_ok=True)
conn.execute("SET memory_limit = '14GB';")  # 보유 RAM의 70~80% 할당
conn.execute("SET threads = 4;")            # CPU 코어 수에 맞게 설정
conn.execute("PRAGMA temp_directory='tmp';")

print("2개의 CSV 파일 스캔 및 event_time 정렬 저장 시작...")
# 3. [핵심] 와일드카드로 2개 파일을 동시에 읽고, event_time 순서로 정렬하여 테이블 생성
# 만약 파일명이 다르면 ['file1.csv', 'file2.csv'] 형태로 넣어도 됩니다.
conn.execute("""
    CREATE TABLE IF NOT EXISTS integrated_events AS 
    SELECT * FROM read_csv_auto('data_part*.csv') 
    ORDER BY event_time;  -- ★ 이 정렬이 Spark급 속도를 내는 치트키입니다.""")
# 4. 블록 스킵(Zone Map) 활성화를 위한 데이터 통계 정보 업데이트
print("인덱스 및 통계 정보 최적화 중...")
conn.execute("ANALYZE integrated_events;")
conn.close()

print(f"성공적으로 변환되었습니다! 생성된 {db_path} 파일 용량을 확인해보세요.")
```

------------------------------
## 2. 왜 이렇게 하면 Spark만큼 빠른가요? (원리 이해)

   1. 와일드카드 병렬 로딩: read_csv_auto('data_part*.csv') 구문은 DuckDB가 내부적으로 멀티스레드를 활용해 두 파일을 동시에 병렬로 읽어 들입니다.
   2. 물리적 정렬(ORDER BY)의 위력: 데이터를 event_time 순서로 정렬해서 저장하면, DuckDB는 데이터를 12만 행씩 묶은 블록마다 최소 시간과 최대 시간을 기록합니다.
   3. 스마트 쿼리(Block Skipping): 나중에 WHERE event_time BETWEEN '2026-07-01' AND '2026-07-02' 같은 쿼리를 날리면, DuckDB는 19GB 전체를 뒤지는 것이 아니라 해당 날짜가 적혀있는 수십 MB의 블록만 디스크에서 콕 집어 읽어옵니다. 이 방식 덕분에 단일 노드에서도 분산 컴퓨팅인 Spark 못지않은 밀리초(ms) 단위 성능이 나옵니다.

------------------------------
## 3. 저장 후 CLI에서 제대로 저장되었는지 확인하기
터미널에서 방금 만든 DB 파일을 열어 조회가 잘 되는지 확인합니다.

duckdb merged_analytics.db

DuckDB 터미널이 열리면 아래 쿼리를 입력해 보세요. 2개 파일의 데이터가 온전히 합쳐졌는지 바로 확인 가능합니다.

-- 총 행(Row) 수 확인SELECT COUNT(*) FROM integrated_events;
-- 특정 날짜 구간 초고속 조회 테스트SELECT event_time, COUNT(*) FROM integrated_events WHERE event_time >= '2026-07-01 00:00:00'GROUP BY event_time LIMIT 10;
-- CLI 종료
.exit

만약 두 CSV 파일의 컬럼 이름이 서로 다르거나, event_time이 2026-07-14 14:46:00 같은 날짜 형태가 아니라 1718349900 같은 숫자로 되어 있다면 추가적인 데이터 타입 변환(Casting)이 필요할 수 있습니다. 두 파일의 헤더(컬럼명) 구조가 동일한지, 그리고 시간 데이터의 형태가 어떻게 되어 있는지 알려주시면 코드를 더 정확하게 튜닝해 드릴 수 있습니다. 컬럼 구조가 서로 같나요?

---

# duckdb의 내부 파티셔닝 기능 - ORDERBY

ORDER BY 자체는 데이터프레임이나 하이브(Hive) 스타일처럼 물리적인 폴더를 쪼개는 파티셔닝(Partitioning)은 아닙니다. 하지만 DuckDB 내부 저장소 구조(ex - mydb.db)에서는 ORDER BY를 해주는 것이 별도의 물리 파티셔닝을 하는 것보다 훨씬 강력한 파티셔닝 효과를 냅니다.
그 이유와 원리를 쉽게 설명해 드리겠습니다.
------------------------------
## 1. DuckDB의 내부 파티셔닝 원리: "논리적 파티셔닝 (Zone Map)"
Spark나 Hive에서 폴더를 year=2026/month=07/로 쪼개는 이유는 "조회할 때 불필요한 폴더(파일)는 읽지 않고 건너뛰기 위해서"입니다.
DuckDB는 폴더를 쪼개는 대신, 하나의 DB 파일 안에서 데이터를 122,880개 행(Row)씩 묶어서 '블록(Row Group)' 단위로 저장합니다. 그리고 각 블록마다 컬럼의 최솟값(Min)과 최댓값(Max)을 기록해 두는데, 이를 지존 맵(Zone Map)이라고 합니다.

* ORDER BY event_time 없이 저장했을 때:
데이터가 뒤죽박죽 섞여 있어서, 모든 블록의 Min~Max 범위가 전체 시간을 포함하게 됩니다. 결국 특정 날짜를 조회해도 모든 블록을 다 열어봐야 합니다 (Full Table Scan).
* ORDER BY event_time으로 정렬해서 저장했을 때:
* 1번 블록: event_time이 2026-07-01 ~ 2026-07-02
   * 2번 블록: event_time이 2026-07-02 ~ 2026-07-03
   * 3번 블록: event_time이 2026-07-03 ~ 2026-07-04

이 상태에서 WHERE event_time = '2026-07-03'이라는 쿼리를 날리면, DuckDB는 1번과 2번 블록은 쳐다보지도 않고 3번 블록(수십 MB)만 디스크에서 쏙 골라서 읽습니다.
물리적으로 폴더만 안 쪼개졌을 뿐, Spark의 파티션 프루닝(Partition Pruning)과 완전히 동일한 메커니즘이 작동하는 것입니다.
------------------------------
## 2. 그래도 "물리적인 폴더 분할"을 원하신다면?
만약 실무 요건상 반드시 눈에 보이는 폴더 구조로 파티션을 나눠서 파일(Parquet)로 가지고 있어야 한다면, ORDER BY가 아니라 PARTITION_BY 옵션을 명시적으로 사용해야 합니다.
이 경우 DuckDB 내부 테이블로 저장하는 것이 아니라, 외부 Parquet 파일 세트로 저장하게 됩니다.

```python
import duckdb
conn = duckdb.connect()
# 2개의 CSV를 읽어서 연(Year), 월(Month)별 물리 폴더로 쪼개어 Parquet로 저장
conn.execute("""
    COPY (
        SELECT *, 
               YEAR(CAST(event_time AS TIMESTAMP)) as ev_year, 
               MONTH(CAST(event_time AS TIMESTAMP)) as ev_month 
        FROM read_csv_auto('data_part*.csv')
    ) 
    TO 'partitioned_output' 
    (FORMAT PARQUET, PARTITION_BY (ev_year, ev_month), OVERWRITE_OR_IGNORE 1);""")
```

이렇게 하면 partitioned_output/ev_year=2026/ev_month=07/data_0.parquet 처럼 Spark와 완전히 똑같은 형태의 물리적 파티션 폴더 구조가 생성됩니다. (이 역시 용량은 대폭 압축됩니다.)
------------------------------
## 결론: 무엇을 선택해야 할까요?

* DuckDB 안에서만 쿼리하고 끝낼 것이다:
👉 ORDER BY를 통한 내부 정렬 저장이 정답입니다. 파일 하나(*.db)로 깔끔하게 관리되면서도 블록 스킵 덕분에 속도가 가장 빠릅니다.
* 이 데이터를 나중에 Spark, Athena, AWS S3 등 다른 시스템에서도 가져가서 쓸 것이다:
👉 PARTITION_BY를 통한 외부 Parquet 분할 저장을 선택해야 합니다.

현재 구축하려는 파이프라인이 DuckDB 단독 분석용인가요, 아니면 타 시스템과의 공유도 고려하고 계시나요? 이에 따라 저장 방식을 확정 지을 수 있습니다.
