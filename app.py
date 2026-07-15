import streamlit as st
import duckdb

# 1. DB 연결 (조회만 할 것이므로 read_only)
con = duckdb.connect('analytics.db', read_only=True)

# 2. 기본 테이블들 5행씩 출력
for t in ["02_session_metrics", "03_user_daily_activity", "04_user_rolling_metrics", "05_user_lifetime_snapshot", "07_user_feature_snapshot", "events"]:
    st.write(f"### {t}")
    st.dataframe(con.execute(f'SELECT * FROM "{t}" LIMIT 5').df())

st.write("---")

# 3. 매크로 테이블 (날짜 인자 1개만 화면에서 직접 받음)
st.write("### 08_user_state_snapshot (Macro)")
date_arg = st.number_input("transition window(days) size : ", 3, step=3) # 날짜 입력창

# 입력받은 날짜로 매크로 즉시 실행
df_macro = con.execute(f"SELECT * FROM get_user_state_transition('{date_arg}') LIMIT 5").df()
st.dataframe(df_macro)

con.close()

# streamlit run app.py