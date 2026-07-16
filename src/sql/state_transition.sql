CREATE OR REPLACE MACRO get_user_state_transition(interval_days) AS TABLE
WITH state_mapping AS (
    -- 1. 기준 시점(T)과 N일 전 시점(T-N)의 상태 데이터를 1:1로 결합
    SELECT
        c.user_id,
        p.snapshot_date AS from_date,
        c.snapshot_date AS to_date,
        
        -- 5대 상태 그룹의 전(p) / 후(c) 값 매핑 (가독성을 위해 Struct나 Pair 형태로 묶어서 결합 준비)
        p.funnel_state AS prev_funnel, c.funnel_state AS curr_funnel,
        p.momentum_state AS prev_momentum, c.momentum_state AS curr_momentum,
        p.browsing_state AS prev_browsing, c.browsing_state AS curr_browsing,
        p.value_state AS prev_value, c.value_state AS curr_value,
        p.context_state AS prev_context, c.context_state AS curr_context
    FROM "08_user_state_snapshot" c
    INNER JOIN "08_user_state_snapshot" p 
       ON c.user_id = p.user_id 
      -- N일 전 데이터를 가져오기 위한 동적 Interval 연산
      AND p.snapshot_date = c.snapshot_date - CAST(interval_days || ' DAY' AS INTERVAL)
),
unpivoted_transitions AS (
    -- 2. [DuckDB 전용 최적화] UNION ALL 5번 대신, 단 1번의 스캔으로 UNPIVOT 처리
    -- 전/후 쌍(Pair)이 모두 존재하는 경우만 한 번에 열을 행으로 내립니다.
    UNPIVOT state_mapping
    ON 
        (prev_funnel, curr_funnel) AS 'Funnel',
        (prev_momentum, curr_momentum) AS 'Momentum',
        (prev_browsing, curr_browsing) AS 'Browsing',
        (prev_value, curr_value) AS 'Value',
        (prev_context, curr_context) AS 'Context'
    INTO 
        NAME state_group
        VALUE previous_state, current_state
)
-- 3. 최종 메트릭 가공 및 필터링
SELECT
    user_id,
    from_date,
    to_date,
    state_group,
    previous_state,
    current_state,
    -- Transition 표현 포맷 정의 (예: New -> Engaged)
    previous_state || ' -> ' || current_state AS transition,
    -- 상태 변화 기간 계산 (일수)
    DATEDIFF('day', from_date, to_date) AS transition_days
FROM unpivoted_transitions
-- 둘 중 하나라도 결측치(NULL)가 존재하는 상태 매핑은 제외하여 데이터 무결성 보장
WHERE previous_state IS NOT NULL 
  AND current_state IS NOT NULL
  ;