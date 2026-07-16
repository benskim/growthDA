SELECT
    snapshot_date,
    funnel_state,
    COUNT(DISTINCT user_id) AS user_count,
    -- BI 툴에서 비율 계산이 안 될 때를 대비한 쿼리 단 비율 계산 (::DOUBLE 적용)
    COUNT(DISTINCT user_id) / SUM(COUNT(DISTINCT user_id)) OVER (PARTITION BY snapshot_date)::DOUBLE AS state_ratio
FROM "08_user_state_snapshot"
GROUP BY 1, 2
ORDER BY 1, 2;

WITH state_transition AS (
    SELECT
        user_id,
        snapshot_date,
        funnel_state AS current_state,
        -- 이전 스냅샷 일자의 상태 가져오기 (DuckDB 윈도우 함수 사용)
        LAG(funnel_state) OVER (
            PARTITION BY user_id 
            ORDER BY snapshot_date
        ) AS previous_state
    FROM "08_user_state_snapshot"
)
SELECT
    previous_state,
    current_state,
    COUNT(DISTINCT user_id) AS transition_user_count
FROM state_transition
-- 첫 날이라 이전 상태가 없는 경우는 제외
WHERE previous_state IS NOT NULL 
GROUP BY 1, 2
ORDER BY 3 DESC;

SELECT
    s.browsing_state,
    s.momentum_state,
    -- 평균 세션 깊이 (정수 나눗셈 방지 ::DOUBLE 적용)
    AVG(f.rolling_event_count / NULLIF(f.active_days, 0)::DOUBLE) AS avg_daily_depth,
    -- 평균 활동 가속도
    AVG(f.activity_acceleration) AS avg_activity_acceleration,
    -- 해당 세그먼트의 유저 수 (버블 크기용)
    COUNT(DISTINCT s.user_id) AS user_count,
    -- 이 세그먼트가 만들어낸 총 매출
    SUM(f.rolling_revenue) AS total_segment_revenue
FROM "08_user_state_snapshot" s
JOIN "07_user_feature_snapshot" f 
  ON s.user_id = f.user_id 
 AND s.snapshot_date = f.snapshot_date
GROUP BY 1, 2
ORDER BY user_count DESC;