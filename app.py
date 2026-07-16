import streamlit as st
import duckdb
import plotly.express as px
import plotly.graph_objects as go

# 1. 페이지 설정 및 DB 연결 (이미 등록된 DB 파일명을 입력하세요)
st.set_page_config(layout="wide", page_title="User Journey Analytics")
st.title("📊 User Journey & Flow Analytics Dashboard")

@st.cache_resource
def get_db_connection():
    return duckdb.connect("analytics.db") # 실제 DuckDB 파일 경로

con = get_db_connection()

# --- 탭 구성 ---
tab1, tab2, tab3 = st.tabs(["📈 1. 퍼널 & 트렌드", "🔄 2. 여정 흐름 (Sankey)", "🎯 3. 가치 보존 (Retention/Momentum)"])

# ==========================================
# Tab 1: 퍼널 & 트렌드 분석
# ==========================================
with tab1:
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("일자별 Funnel State 구성 비율 추이")
        df_trend = con.execute("""
            SELECT snapshot_date, funnel_state, COUNT(DISTINCT user_id) AS user_count,
                   COUNT(DISTINCT user_id) / SUM(COUNT(DISTINCT user_id)) OVER (PARTITION BY snapshot_date)::DOUBLE AS state_ratio
            FROM "08_user_state_snapshot"
            WHERE snapshot_date BETWEEN '2026-06-15' AND '2026-07-15'
            GROUP BY 1, 2 ORDER BY 1, 2;
        """).df()
        
        st.plotly_chart(px.area(
            df_trend, x="snapshot_date", y="state_ratio", color="funnel_state",
            labels={"state_ratio": "비율", "snapshot_date": "날짜"},
            category_orders={"funnel_state": ["New Visitor", "Engaged", "Activated", "Repeated", "Expanded"]}
        ), use_container_width=True)
        
    with col2:
        st.subheader("기간 내 누적 퍼널 (최종 도달 상태 기준)")
        df_funnel = con.execute("""
            WITH user_max_state AS (
                SELECT user_id,
                    CASE MAX(CASE funnel_state WHEN 'New Visitor' THEN 1 WHEN 'Engaged' THEN 2 WHEN 'Activated' THEN 3 WHEN 'Repeated' THEN 4 WHEN 'Expanded' THEN 5 ELSE 0 END)
                        WHEN 1 THEN 'New Visitor' WHEN 2 THEN 'Engaged' WHEN 3 THEN 'Activated' WHEN 4 THEN 'Repeated' WHEN 5 THEN 'Expanded'
                    END AS max_funnel_state
                FROM "08_user_state_snapshot"
                WHERE snapshot_date BETWEEN '2026-06-15' AND '2026-07-15'
                GROUP BY user_id
            )
            SELECT max_funnel_state AS funnel_state, COUNT(DISTINCT user_id) AS user_count
            FROM user_max_state GROUP BY max_funnel_state
            ORDER BY CASE max_funnel_state WHEN 'New Visitor' THEN 1 WHEN 'Engaged' THEN 2 WHEN 'Activated' THEN 3 WHEN 'Repeated' THEN 4 WHEN 'Expanded' THEN 5 END;
        """).df()
        
        st.plotly_chart(px.funnel(df_funnel, x="user_count", y="funnel_state"), use_container_width=True)

# ==========================================
# Tab 2: 여정 흐름 (이미 등록된 get_user_state_transition 활용)
# ==========================================
with tab2:
    st.subheader("유저 상태 전이 분석 (Sankey Flow)")
    col_s1, col_s2 = st.columns([1, 4])
    
    with col_s1:
        state_group = st.selectbox("상태 그룹 선택", ["Funnel", "Momentum", "Browsing", "Value", "Context"])
        interval_days = st.slider("전이 추적 간격 (일)", min_value=1, max_value=14, value=3)

    df_sankey = con.execute(f"""
        SELECT previous_state AS source, current_state AS target, COUNT(DISTINCT user_id) AS value
        FROM get_user_state_transition({interval_days})
        WHERE state_group = '{state_group}'
          AND previous_state IS NOT NULL
          AND previous_state != current_state 
        GROUP BY 1, 2 ORDER BY 3 DESC;
    """).df()

    if not df_sankey.empty:
        all_nodes = list(set(df_sankey['source'].tolist() + df_sankey['target'].tolist()))
        node_map = {node: i for i, node in enumerate(all_nodes)}
        
        fig_sankey = go.Figure(data=[go.Sankey(
            node=dict(pad=15, thickness=20, line=dict(color="black", width=0.5), label=all_nodes),
            link=dict(source=df_sankey['source'].map(node_map), target=df_sankey['target'].map(node_map), value=df_sankey['value'])
        )])
        st.plotly_chart(fig_sankey, use_container_width=True)
    else:
        st.warning("선택한 조건에 매칭되는 흐름 데이터가 없습니다.")

# ==========================================
# Tab 3: 가치 보존 및 모멘텀 (이미 등록된 get_behavioral_retention 활용)
# ==========================================
with tab3:
    col_r1, col_r2 = st.columns(2)
    
    with col_r1:
        st.subheader("가치 행동 잔존율 (Cohort Behavior Retention)")
        bucket_size = st.radio("코호트 분석 간격 선택", [1, 3, 5, 7], index=1, horizontal=True)
        
        # 1. 매크로 호출 및 데이터 가공
        df_ret = con.execute(f"SELECT * FROM get_behavioral_retention({bucket_size});").df()
        df_pivot = df_ret.pivot(index="cohort_date", columns="period_label", values="state_retention_rate")
        df_pivot = df_pivot.fillna(0.0)
        
        # 2. 정렬
        sorted_columns = sorted(df_pivot.columns, key=lambda x: int(x.split('-')[0].replace('Day ', '')))
        df_pivot = df_pivot.reindex(columns=sorted_columns)
        df_pivot = df_pivot.sort_index(ascending=True)

        # 3. 단색 톤(Blues) 히트맵 그리기
        # 'Blues' 컬러맵은 100%일 때 아주 진한 블루, 0%에 가까워질수록 투명에 가까운 아주 연한 블루가 됩니다.
        fig_heat = px.imshow(
            df_pivot, 
            text_auto=".1%",                      # 텍스트 포맷 (예: 50.0%)
            color_continuous_scale="Blues",       # 단색 점진 톤 적용 (Blues, Purples, Greens 등 선택 가능)
            labels=dict(x="경과 기간", y="코호트 시작일(Activated)", color="잔존율"),
            aspect="auto"
        )
        
        # 4. 레이아웃 튜닝 (시각적 일관성 확보)
        fig_heat.update_layout(
            coloraxis_showscale=True,
            # 배경 격자나 텍스트 컬러가 가독성 있게 보이도록 조정
            plot_bgcolor="white"
        )
        fig_heat.update_coloraxes(
            colorbar_tickformat=".0%",
            cmin=0.0,  # 컬러맵의 최솟값을 0%로 고정
            cmax=1.0   # 컬러맵의 최댓값을 100%로 고정 (값이 뭉개지지 않게 방지)
        )
        
        st.plotly_chart(fig_heat, use_container_width=True)
        
    with col_r2:
        st.subheader("Momentum & Browsing State 다이내믹 분석")
        df_mom = con.execute("""
            SELECT s.browsing_state, s.momentum_state,
                   AVG(f.rolling_event_count / NULLIF(f.active_days, 0)::DOUBLE) AS avg_daily_depth,
                   AVG(f.activity_acceleration) AS avg_activity_acceleration,
                   COUNT(s.user_id) AS user_count
            FROM "08_user_state_snapshot" s
            JOIN "07_user_feature_snapshot" f ON s.snapshot_date = f.snapshot_date AND s.user_id = f.user_id
            WHERE s.snapshot_date BETWEEN '2026-06-15' AND '2026-07-15'
              AND f.snapshot_date BETWEEN '2026-06-15' AND '2026-07-15'
            GROUP BY 1, 2 ORDER BY user_count DESC;
        """).df()
        
        st.plotly_chart(px.scatter(
            df_mom, x="avg_daily_depth", y="avg_activity_acceleration",
            size="user_count", color="browsing_state", hover_name="momentum_state",
            labels={"avg_daily_depth": "평균 일간 탐색 깊이 (Depth)", "avg_activity_acceleration": "활동 가속도 (Acceleration)"},
            size_max=60
        ), use_container_width=True)

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