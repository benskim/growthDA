-- #0. 일자별 유저 funnel state 구성비율 변화추이
SELECT
    snapshot_date,
    funnel_state,
    COUNT(DISTINCT user_id) AS user_count,
    -- 날짜별 전체 유저 대비 특정 상태의 유저 비중 (::DOUBLE)
    COUNT(DISTINCT user_id) / SUM(COUNT(DISTINCT user_id)) OVER (PARTITION BY snapshot_date)::DOUBLE AS state_ratio
FROM "08_user_state_snapshot"
WHERE snapshot_date BETWEEN '2026-06-15' AND '2026-07-15'
GROUP BY 1, 2
ORDER BY 1, 2;

-- #1. cumulative funnel state chart
WITH user_max_state AS (
    -- 1. 분석 기간 내 유저별로 도달한 가장 높은 단계(우선순위) 정의
    SELECT
        user_id,
        -- 각 상태에 점수를 매겨 가장 큰 점수의 상태를 선택
        CASE MAX(
            CASE funnel_state
                WHEN 'New Visitor' THEN 1
                WHEN 'Engaged'     THEN 2
                WHEN 'Activated'   THEN 3
                WHEN 'Repeated'    THEN 4
                WHEN 'Expanded'    THEN 5
                ELSE 0
            END
        )
            WHEN 1 THEN 'New Visitor'
            WHEN 2 THEN 'Engaged'
            WHEN 3 THEN 'Activated'
            WHEN 4 THEN 'Repeated'
            WHEN 5 THEN 'Expanded'
        END AS max_funnel_state
    FROM "08_user_state_snapshot"
    WHERE snapshot_date BETWEEN '2026-06-15' AND '2026-07-15'
    GROUP BY user_id
)
-- 2. 중복이 제거된 유저별 최종 상태를 기준으로 깔때기 집계
SELECT
    max_funnel_state AS funnel_state,
    COUNT(DISTINCT user_id) AS user_count,
    -- 전체 고유 유저 대비 비율 (::DOUBLE 적용)
    COUNT(DISTINCT user_id) / SUM(COUNT(DISTINCT user_id)) OVER ()::DOUBLE AS total_ratio
FROM user_max_state
GROUP BY max_funnel_state
ORDER BY 
    CASE max_funnel_state
        WHEN 'New Visitor' THEN 1
        WHEN 'Engaged'     THEN 2
        WHEN 'Activated'   THEN 3
        WHEN 'Repeated'    THEN 4
        WHEN 'Expanded'    THEN 5
    END;

-- # 2. sankey chart
-- 기존에 동일한 이름의 매크로가 있다면 드랍
DROP MACRO IF EXISTS get_cumulative_state_transition;

-- N일 간격을 매개변수로 받는 매크로 생성
CREATE OR REPLACE MACRO get_cumulative_state_transition(interval_days) AS TABLE
WITH base_dates AS (
    -- 분석 기준이 되는 최초 스냅샷 일자 정의 (데이터 범위에 맞게 조정 가능)
    SELECT MIN(snapshot_date) AS min_date FROM user_state_snapshot
),
first_state_cohort AS (
    -- 1. 코호트 진입 시점(최초 상태) 정의
    SELECT 
        u.user_id,
        u.state AS first_state,
        u.snapshot_date AS first_date
    FROM user_state_snapshot u, base_dates b
    WHERE u.snapshot_date = b.min_date
),
last_state_cohort AS (
    -- 2. 최초 시점으로부터 정확히 interval_days만큼 지난 날짜의 최종 상태 추출
    SELECT 
        u.user_id,
        u.state AS last_state,
        u.snapshot_date AS last_date
    FROM user_state_snapshot u, base_dates b
    WHERE u.snapshot_date = b.min_date + CAST(interval_days AS INTEGER)
),
transitions AS (
    -- 3. 1:1로 레프트 조인하여 잔존 및 Churn(이탈) 매핑
    SELECT 
        f.user_id,
        f.first_state,
        COALESCE(l.last_state, 'Churned') AS last_state
    FROM first_state_cohort f
    LEFT JOIN last_state_cohort l ON f.user_id = l.user_id
)
-- 4. Sankey 시각화를 위해 최종 집계 및 노드 분리 처리를 위한 접두사 인코딩
SELECT 
    '0. ' || first_state AS source,
    '1. ' || last_state AS target,
    COUNT(DISTINCT user_id) AS value
FROM transitions
GROUP BY first_state, last_state;

-- # 3. valuable state retention chart
-- ⚠️ 3일, 5일, 7일 등으로 변경하고 싶을 때 매크로 인자값(bucket_size)을 조절합니다.
CREATE OR REPLACE MACRO get_behavioral_retention(bucket_size) AS TABLE
WITH real_new_users AS (
    -- 1. 데이터 절단 왜곡 방지: 6월 15일 이후 가입한 순수 신규 유저 필터링
    SELECT 
        user_id,
        first_activity_date
    FROM "05_user_lifetime_snapshot"
    WHERE first_activity_date >= '2026-06-15'
),
user_activation_cohort AS (
    -- 2. 순수 신규 유저가 최초로 'Activated' 상태에 도달한 날을 코호트 기준으로 정의
    SELECT 
        s.user_id,
        MIN(s.snapshot_date) AS cohort_date
    FROM "08_user_state_snapshot" s
    JOIN real_new_users r ON s.user_id = r.user_id
    WHERE s.funnel_state = 'Activated'
    GROUP BY 1
),
retention_raw AS (
    -- 3. 활성화 이후 일자별 스냅샷 데이터를 조인하여 '경과 일수' 계산
    SELECT
        c.user_id,
        c.cohort_date,
        s.snapshot_date,
        DATEDIFF('day', c.cohort_date, s.snapshot_date) AS days_since_cohort,
        -- 여전히 가치 있는 상태를 유지하고 있는지 여부
        CASE 
            WHEN s.funnel_state IN ('Activated', 'Repeated', 'Expanded') THEN 1 
            ELSE 0 
        END AS is_retained
    FROM user_activation_cohort c
    JOIN "08_user_state_snapshot" s ON c.user_id = s.user_id
    WHERE s.snapshot_date >= c.cohort_date
      AND DATEDIFF('day', c.cohort_date, s.snapshot_date) <= 30
),
retention_buckets AS (
    -- 4. [핵심] 경과 일수를 사용자가 지정한 bucket_size로 나누어 '구간' 정의
    -- 예: bucket_size가 3일 때, 0~2일차 -> 0번 버킷 / 3~5일차 -> 1번 버킷 / 6~8일차 -> 2번 버킷
    SELECT
        user_id,
        cohort_date,
        (days_since_cohort / bucket_size)::INT AS bucket_index,
        MAX(is_retained) AS retained_in_bucket -- 해당 버킷 기간 내 단 한 번이라도 잔존했다면 1
    FROM retention_raw
    GROUP BY 1, 2, 3
),
cohort_sizes AS (
    -- 5. 코호트 일자별 가입 모수 계산
    SELECT 
        cohort_date,
        COUNT(DISTINCT user_id) AS cohort_size
    FROM user_activation_cohort
    GROUP BY 1
)
-- 6. 최종 버킷(구간) 단위 가치 잔존율 계산
SELECT
    r.cohort_date,
    -- 시각화 가독성을 위해 "Day 0-2", "Day 3-5" 같은 라벨을 동적으로 생성
    'Day ' || (r.bucket_index * bucket_size) || '-' || ((r.bucket_index + 1) * bucket_size - 1) AS period_label,
    r.bucket_index,
    SUM(r.retained_in_bucket) AS retained_users,
    sz.cohort_size,
    SUM(r.retained_in_bucket) / sz.cohort_size::DOUBLE AS state_retention_rate
FROM retention_buckets r
JOIN cohort_sizes sz ON r.cohort_date = sz.cohort_date
GROUP BY 1, 2, 3, 5
ORDER BY r.cohort_date, r.bucket_index;

-- #4. momentum & browsing state chart
SELECT
    s.browsing_state,
    s.momentum_state,
    -- 평균 세션 깊이 (정밀한 연산을 위해 나눗셈 후 AVG 처리)
    AVG(f.rolling_event_count / NULLIF(f.active_days, 0)::DOUBLE) AS avg_daily_depth,
    -- 평균 활동 및 구매 가속도
    AVG(f.activity_acceleration) AS avg_activity_acceleration,
    AVG(f.purchase_acceleration) AS avg_purchase_acceleration,
    
    -- [최적화] DISTINCT 제거: 일자별 스냅샷이므로 단순 COUNT가 훨씬 빠르고 메모리를 덜 먹습니다.
    COUNT(s.user_id) AS user_count,
    
    -- 해당 그룹의 총 매출 기여도
    SUM(f.rolling_revenue) AS total_segment_revenue
FROM "08_user_state_snapshot" s
-- [최적화] 동일한 날짜 범위 조건(Filter)이 양쪽 테이블 스캔 시점에 적용되도록 유도
JOIN "07_user_feature_snapshot" f 
  ON s.snapshot_date = f.snapshot_date  -- 날짜 조인을 먼저 배치하여 파티션  pruning 유도
 AND s.user_id = f.user_id
WHERE s.snapshot_date BETWEEN '2026-06-15' AND '2026-07-15'
  AND f.snapshot_date BETWEEN '2026-06-15' AND '2026-07-15' -- 명시적 필터 추가
GROUP BY 1, 2
ORDER BY user_count DESC;