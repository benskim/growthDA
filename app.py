import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import duckdb  # 👈 DuckDB 라이브러리 추가 필요!

st.set_page_config(layout="wide", page_title="User Journey")
st.title("📊 User Journey Dashboard (6/15 ~ 7/15)")

# 1. 30일 데이터 기간 슬라이더
start_date, end_date = st.slider(
    "조회 기간 선택",
    min_value=pd.to_datetime("2026-06-15"),
    max_value=pd.to_datetime("2026-07-15"),
    value=(pd.to_datetime("2026-06-15"), pd.to_datetime("2026-07-15")),
    format="MM-DD"
)

# 2. DuckDB 연결 및 데이터 로드 함수 (st.cache_data로 매번 DB를 읽는 부하를 방지)
@st.cache_data
def get_data_from_duckdb():
    # 📌 보유하고 계신 duckdb 파일 경로를 적어줍니다 (예: 'my_data.db'). 
    # 만약 메모리 DB라면 ':memory:'를 사용합니다.
    con = duckdb.connect("analytics.db") 
    
    # [차트 1] 날짜별 상태 비중 데이터 가져오기 (08_user_state_snapshot)
    # 정수 나눗셈 방지를 위해 이전에 수정한 double casting 적용 가능
    query_area = """
        SELECT 
            snapshot_date, 
            funnel_state, 
            COUNT(DISTINCT user_id) AS user_count
        FROM "08_user_state_snapshot"
        GROUP BY 1, 2
        ORDER BY 1, 2
    """
    df_area = con.execute(query_area).df()
    df_area["snapshot_date"] = pd.to_datetime(df_area["snapshot_date"])
    
    # [차트 2] 상태 이동(Sankey) 데이터 가져오기
    # LAG 윈도우 함수를 통해 전날 대비 오늘 상태 변화를 계산하는 쿼리입니다.
    query_trans = """
        WITH state_transition AS (
            SELECT
                user_id,
                snapshot_date,
                funnel_state AS current_state,
                LAG(funnel_state) OVER (
                    PARTITION BY user_id 
                    ORDER BY snapshot_date
                ) AS previous_state
            FROM "08_user_state_snapshot"
        )
        SELECT
            previous_state AS "from",
            current_state AS "to",
            COUNT(DISTINCT user_id) AS "count"
        FROM state_transition
        WHERE previous_state IS NOT NULL AND previous_state != current_state
        GROUP BY 1, 2
        ORDER BY 3 DESC
    """
    df_trans = con.execute(query_trans).df()
    
    # 사용이 끝난 커넥션은 닫아줍니다.
    con.close()
    
    return df_area, df_trans

# 실제 DB에서 데이터 로드
try:
    df_area, df_trans = get_data_from_duckdb()
except Exception as e:
    st.error(f"⚠️ DuckDB 연결 실패! 파일 경로와 테이블명을 확인해 주세요.\n에러 내용: {e}")
    st.stop()

# 3. 슬라이더 날짜 필터링 적용
filtered_area = df_area[(df_area["snapshot_date"] >= start_date) & (df_area["snapshot_date"] <= end_date)]

# 4. 화면 레이아웃 (반반 분할)
col1, col2 = st.columns(2)

with col1:
    st.subheader("📈 날짜별 상태 비중 (100%)")
    fig1 = px.area(filtered_area, x="snapshot_date", y="user_count", color="funnel_state", groupnorm="percent")
    st.plotly_chart(fig1, use_container_width=True)

with col2:
    st.subheader("🔄 유저 상태 전이 (Sankey)")
    all_nodes = list(set(df_trans["from"]).union(set(df_trans["to"])))
    node_map = {name: i for i, name in enumerate(all_nodes)}
    
    fig2 = go.Figure(data=[go.Sankey(
        node = dict(pad=15, thickness=20, label=all_nodes, color="royalblue"),
        link = dict(
            source=df_trans["from"].map(node_map),
            target=df_trans["to"].map(node_map),
            value=df_trans["count"],
            color="rgba(100, 149, 237, 0.4)"
        )
    )])
    st.plotly_chart(fig2, use_container_width=True, theme=None)

# import streamlit as st
# import duckdb

# # 1. DB 연결 (조회만 할 것이므로 read_only)
# con = duckdb.connect('analytics.db', read_only=True)

# # 2. 기본 테이블들 5행씩 출력
# for t in ["02_session_metrics", "03_user_daily_activity", "04_user_rolling_metrics", "05_user_lifetime_snapshot", "07_user_feature_snapshot", "events"]:
#     st.write(f"### {t}")
#     st.dataframe(con.execute(f'SELECT * FROM "{t}" LIMIT 5').df())

# st.write("---")

# # 3. 매크로 테이블 (날짜 인자 1개만 화면에서 직접 받음)
# st.write("### 08_user_state_snapshot (Macro)")
# date_arg = st.number_input("transition window(days) size : ", 3, step=3) # 날짜 입력창

# # 입력받은 날짜로 매크로 즉시 실행
# df_macro = con.execute(f"SELECT * FROM get_user_state_transition('{date_arg}') LIMIT 5").df()
# st.dataframe(df_macro)

# con.close()

# streamlit run app.py