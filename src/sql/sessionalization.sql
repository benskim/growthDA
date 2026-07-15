
-- session hash/id를 더 쪼개고 싶을 때, 사용.

WITH price_lag AS (
    SELECT 
        user_id,
        session_id,
        event_time,
        price,
        -- 기존 세션 내부에서 이전 상품의 가격 가져오기
        LAG(price) OVER (
            PARTITION BY user_id, session_id 
            ORDER BY event_time
        ) AS prev_price
    FROM "events"
),
session_splitter AS (
    SELECT 
        *,
        -- 이전 가격과 현재 가격의 차이가 2배 이상 나면 분할 트리거(1) 발생
        -- (비즈니스 룰에 따라 'ABS(price - prev_price) > 100000' 등으로 변경 가능)
        CASE 
            WHEN prev_price IS NOT NULL AND (price >= prev_price * 2.0 OR price <= prev_price / 2.0) THEN 1
            ELSE 0
        END AS is_new_price_segment
    FROM price_lag
),
new_session_id_calc AS (
    SELECT 
        *,
        -- 기존 session_id 뒤에 가격 세션 누적합(Sum)을 붙여 고유한 하이브리드 세션 ID 생성
        session_id || '_' || SUM(is_new_price_segment) OVER (
            PARTITION BY user_id, session_id 
            ORDER BY event_time
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS price_session_id
    FROM session_splitter
)
SELECT * FROM new_session_id_calc;

CREATE OR REPLACE TABLE "02_session_metrics" AS
WITH session_base AS (
    SELECT
        -- [변경] 기존 session_id 대신 가격 분할이 적용된 price_session_id 사용
        price_session_id AS session_id, 
        user_id,
        COUNT(*) AS session_event_count,
        COUNT(*) FILTER(event_type = 'view') AS session_view_count,
        COUNT(*) FILTER(event_type = 'cart') AS session_cart_count,
        COUNT(*) FILTER(event_type = 'purchase') AS session_purchase_count,
        COUNT(DISTINCT product_id) AS product_diversity,
        COUNT(DISTINCT category_id) AS category_diversity,
        COUNT(DISTINCT brand) AS brand_diversity,
        SUM(price) FILTER(event_type = 'purchase') AS session_revenue,
        MIN(event_time) AS session_start_time,
        MAX(event_time) AS session_end_time,
        ANY_VALUE(device) AS device,
        ANY_VALUE(channel) AS channel
    -- [변경] 원천 events 대신 위 Step 1의 가격 세션화된 뷰/CTE를 소스로 사용
    FROM price_session_events 
    GROUP BY price_session_id, user_id
)
SELECT
    session_id,
    user_id,
    CAST(session_start_time AS DATE) AS session_start_date,
    session_event_count,
    session_view_count,
    session_cart_count,
    session_purchase_count,
    product_diversity AS product_diversity_count,
    category_diversity AS category_diversity_count,
    brand_diversity AS brand_diversity_count,
    COALESCE(session_revenue, 0) AS session_revenue,
    session_start_time,
    session_end_time,
    device,
    channel,
    
    -- Derived Features
    EPOCH(session_end_time - session_start_time) AS session_duration_seconds,
    session_event_count AS session_depth,
    CASE 
        WHEN product_diversity > 0 THEN CAST(session_event_count AS DOUBLE) / product_diversity 
        ELSE 0 
    END AS product_repeat_rate,
    CASE 
        WHEN session_purchase_count > 0 THEN COALESCE(session_revenue, 0) / session_purchase_count 
        ELSE 0 
    END AS session_aov
FROM session_base
ORDER BY session_start_date, user_id;