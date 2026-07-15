CREATE OR REPLACE MACRO get_user_state_transition(interval_days) AS TABLE
WITH state_mapping AS (
    -- 기준 시점(T)과 N일 전 시점(T-N)의 상태 데이터를 1:1로 결합
    SELECT
        c.user_id,
        p.snapshot_date AS from_date,
        c.snapshot_date AS to_date,
        
        -- 5대 상태 그룹의 전(T-N) / 후(T) 값 매핑
        p.funnel_state AS prev_funnel,
        c.funnel_state AS curr_funnel,
        
        p.momentum_state AS prev_momentum,
        c.momentum_state AS curr_momentum,
        
        p.browsing_state AS prev_browsing,
        c.browsing_state AS curr_browsing,
        
        p.value_state AS prev_value,
        c.value_state AS curr_value,
        
        p.context_state AS prev_context,
        c.context_state AS curr_context
    FROM "08_user_state_snapshot" c
    INNER JOIN "08_user_state_snapshot" p 
       ON c.user_id = p.user_id 
      -- N일 전 데이터를 가져오기 위한 동적 Interval 연산
      AND p.snapshot_date = c.snapshot_date - CAST(interval_days || ' DAY' AS INTERVAL)
),
unpivoted_transitions AS (
    -- [초안 반영] 5가지 상태 그룹 데이터를 표준 Transition 포맷으로 Unpivot 처리
    SELECT 
        user_id, from_date, to_date, 
        'Funnel' AS state_group, prev_funnel AS previous_state, curr_funnel AS current_state 
    FROM state_mapping WHERE prev_funnel IS NOT NULL AND curr_funnel IS NOT NULL
    
    UNION ALL
    
    SELECT 
        user_id, from_date, to_date, 
        'Momentum' AS state_group, prev_momentum AS previous_state, curr_momentum AS current_state 
    FROM state_mapping WHERE prev_momentum IS NOT NULL AND curr_momentum IS NOT NULL
    
    UNION ALL
    
    SELECT 
        user_id, from_date, to_date, 
        'Browsing' AS state_group, prev_browsing AS previous_state, curr_browsing AS current_state 
    FROM state_mapping WHERE prev_browsing IS NOT NULL AND curr_browsing IS NOT NULL
    
    UNION ALL
    
    SELECT 
        user_id, from_date, to_date, 
        'Value' AS state_group, prev_value AS previous_state, curr_value AS current_state 
    FROM state_mapping WHERE prev_value IS NOT NULL AND curr_value IS NOT NULL
    
    UNION ALL
    
    SELECT 
        user_id, from_date, to_date, 
        'Context' AS state_group, prev_context AS previous_state, curr_context AS current_state 
    FROM state_mapping WHERE prev_context IS NOT NULL AND curr_context IS NOT NULL
)
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
    EPOCH(CAST(to_date AS TIMESTAMP) - CAST(from_date AS TIMESTAMP)) / 86400 AS transition_days
FROM unpivoted_transitions;

-- 3일 간격 전이를 보고 싶을 때
-- SELECT * FROM get_user_state_transition(3) LIMIT 10;

-- 11일 간격 전이를 보고 싶을 때
-- SELECT * FROM get_user_state_transition(11) LIMIT 10;