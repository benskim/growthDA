CREATE OR REPLACE TABLE "02_session_metrics" AS
WITH session_base AS (
    SELECT
        user_session as session_id,
        user_id,
        -- Original Features
        COUNT(*) AS session_event_count,
        COUNT(*) FILTER(event_type = 'view') AS session_view_count,
        COUNT(*) FILTER(event_type = 'cart') AS session_cart_count,
        COUNT(*) FILTER(event_type = 'purchase') AS session_purchase_count,
        COUNT(DISTINCT product_id) AS product_diversity,
        COUNT(DISTINCT category_code) AS category_diversity,
        COUNT(DISTINCT brand) AS brand_diversity,
        SUM(price) FILTER(event_type = 'purchase') AS session_revenue,
        MIN(event_time) AS session_start_time,
        MAX(event_time) AS session_end_time,
        ANY_VALUE(device) AS device,
        ANY_VALUE(channel) AS channel
    FROM "events"
    GROUP BY session_id, user_id
)
SELECT
    session_id,
    user_id,
    CAST(session_start_time AS DATE) AS session_start_date,
    
    -- Original Features
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
    EPOCH(session_end_time - session_start_time) AS session_duration_seconds, -- End Time - Start Time
    session_event_count AS session_depth,
    CASE 
        WHEN product_diversity > 0 THEN CAST(session_event_count AS DOUBLE) / NULLIF(product_diversity, 0) 
        ELSE 0 
    END AS product_repeat_rate,
    CASE 
        WHEN session_purchase_count > 0 THEN COALESCE(session_revenue, 0) / NULLIF(session_purchase_count, 0) 
        ELSE 0 
    END AS session_aov
FROM session_base
ORDER BY session_start_date, user_id;

CREATE OR REPLACE TABLE "03_user_daily_activity" AS
WITH daily_events AS (
    -- events 테이블 집계
    SELECT
        user_id,
        CAST(event_time AS DATE) AS activity_date,
        COUNT(*) AS event_count,
        COUNT(*) FILTER(event_type = 'view') AS view_count,
        COUNT(*) FILTER(event_type = 'cart') AS cart_count,
        COUNT(*) FILTER(event_type = 'purchase') AS purchase_count,
        MAX(CAST(event_time AS DATE)) AS last_activity_date,
        MAX(CAST(event_time AS DATE)) FILTER(event_type = 'purchase') AS last_purchase_date,
        COUNT(DISTINCT product_id) AS product_diversity_count,
        COUNT(DISTINCT category_code) AS category_diversity_count,
        COUNT(DISTINCT brand) AS brand_diversity_count,
        SUM(price) FILTER(event_type = 'view') AS sum_viewed_revenue, -- [추가] 조회 시 가격 합계
        SUM(price) FILTER(event_type = 'purchase') AS revenue,
        AVG(price) FILTER(event_type = 'view') AS avg_viewed_price,
        AVG(price) FILTER(event_type = 'purchase') AS avg_purchased_price,
        MAX(price) FILTER(event_type = 'purchase') AS max_purchase_price,
        MIN(EXTRACT(hour FROM event_time)) AS first_active_hour,
        MAX(EXTRACT(hour FROM event_time)) AS last_active_hour,
        
        -- 주말 여부 (DuckDB: 0은 일요일, 6은 토요일)
        SUM(CASE WHEN EXTRACT(dayofweek FROM event_time) IN (0, 6) THEN 1 ELSE 0 END) AS weekend_count,
        COUNT(DISTINCT device) AS unique_device_count,
        COUNT(DISTINCT channel) AS unique_channel_count,
        STDDEV(price) AS price_diversity
    FROM "events"
    GROUP BY 1,2
    -- GROUP BY user_id, CAST(event_time AS DATE)
),
daily_sessions AS (
    -- session_metrics 테이블 요약 집계
    SELECT
        user_id,
        session_start_date AS activity_date,
        COUNT(*) AS session_count,
        AVG(session_duration_seconds) AS avg_session_duration,
        AVG(session_depth) AS avg_session_depth
    FROM "02_session_metrics"
    GROUP BY user_id, session_start_date
),
category_entropy_prep AS (
    -- 카테고리 엔트로피 사전 계산
    SELECT 
        user_id,
        activity_date,
        -SUM((cnt / total_cnt) * LN(cnt / total_cnt)) AS category_entropy
    FROM (
        SELECT 
            user_id,
            CAST(event_time AS DATE) AS activity_date,
            category_code,
            COUNT(*) AS cnt,
            SUM(COUNT(*)) OVER(PARTITION BY user_id, CAST(event_time AS DATE)) AS total_cnt
        FROM "events"
        WHERE category_code IS NOT NULL
        GROUP BY user_id, CAST(event_time AS DATE), category_code
    )
    GROUP BY user_id, activity_date
),
brand_entropy_prep AS (
    -- 브랜드 엔트로피 사전 계산
    SELECT 
        user_id,
        activity_date,
        -SUM((cnt / total_cnt) * LN(cnt / total_cnt)) AS brand_entropy
    FROM (
        SELECT 
            user_id,
            CAST(event_time AS DATE) AS activity_date,
            brand,
            COUNT(*) AS cnt,
            SUM(COUNT(*)) OVER(PARTITION BY user_id, CAST(event_time AS DATE)) AS total_cnt
        FROM "events"
        WHERE brand IS NOT NULL
        GROUP BY user_id, CAST(event_time AS DATE), brand
    )
    GROUP BY user_id, activity_date
)
SELECT
    e.user_id,
    e.activity_date,
    
    -- Original Features
    e.event_count,
    COALESCE(s.session_count, 0) AS session_count,
    e.view_count,
    e.cart_count,
    e.purchase_count,
    1 AS active_day, -- Constant 1
    e.last_activity_date,
    e.last_purchase_date,
    e.product_diversity_count,
    e.category_diversity_count,
    e.brand_diversity_count,
    COALESCE(e.revenue, 0) AS revenue,
    COALESCE(e.sum_viewed_revenue, 0) AS sum_viewed_revenue,
    -- e.avg_viewed_price,
    -- e.avg_purchased_price,
    e.max_purchase_price,
    e.first_active_hour,
    e.last_active_hour,
    e.weekend_count,
    e.unique_device_count,
    e.unique_channel_count,
    
    -- Derived Features
    COALESCE(s.avg_session_duration, 0) AS avg_session_duration,
    COALESCE(s.avg_session_depth, 0) AS avg_session_depth,
    COALESCE(ce.category_entropy, 0) AS category_entropy,
    COALESCE(be.brand_entropy, 0) AS brand_entropy,
    COALESCE(e.price_diversity, 0) AS price_diversity,
    CASE 
        WHEN e.purchase_count > 0 THEN COALESCE(e.revenue, 0) / nullif(e.purchase_count, 0) 
        ELSE 0 
    END AS average_order_value,
    CASE 
        WHEN e.event_count > 0 THEN CAST(e.weekend_count AS DOUBLE) / nullif(e.event_count, 0)
        ELSE 0 
    END AS weekend_ratio
FROM daily_events e
LEFT JOIN daily_sessions s ON e.user_id = s.user_id AND e.activity_date = s.activity_date
LEFT JOIN category_entropy_prep ce ON e.user_id = ce.user_id AND e.activity_date = ce.activity_date
LEFT JOIN brand_entropy_prep be ON e.user_id = be.user_id AND e.activity_date = be.activity_date
ORDER BY e.activity_date, e.user_id;


CREATE OR REPLACE TABLE "04_user_rolling_metrics" AS
WITH date_spine AS (
    SELECT DISTINCT user_id, activity_date AS snapshot_date
    FROM "03_user_daily_activity"
),
additive_rolling AS (
    SELECT
        d.user_id,
        d.snapshot_date,
        SUM(a.event_count) AS rolling_event_count,
        SUM(a.session_count) AS rolling_session_count,
        SUM(a.view_count) AS rolling_view_count,
        SUM(a.cart_count) AS rolling_cart_count,
        SUM(a.purchase_count) AS rolling_purchase_count,
        SUM(a.active_day) AS active_days,
        MAX(a.last_activity_date) AS last_activity_date,
        MAX(a.last_purchase_date) AS last_purchase_date,
        SUM(a.revenue) AS rolling_revenue,
        SUM(a.sum_viewed_revenue) AS rolling_sum_viewed_revenue,
        -- AVG(a.avg_viewed_price) AS avg_viewed_price,
        -- AVG(a.avg_purchased_price) AS avg_purchased_price, 위 컬럼으로 대체
        MAX(a.max_purchase_price) AS max_purchase_price,
        SUM(a.weekend_count) AS weekend_count,
        
        -- 가속도/성장 계산을 위한 당일 지표 임시 확보
        SUM(CASE WHEN a.activity_date = d.snapshot_date THEN a.event_count ELSE 0 END) AS today_event_count,
        SUM(CASE WHEN a.activity_date = d.snapshot_date THEN a.purchase_count ELSE 0 END) AS today_purchase_count,
        SUM(CASE WHEN a.activity_date = d.snapshot_date THEN a.revenue ELSE 0 END) AS today_revenue,
        SUM(CASE WHEN a.activity_date = d.snapshot_date THEN a.session_count ELSE 0 END) AS today_session,
        SUM(CASE WHEN a.activity_date = d.snapshot_date - INTERVAL '1 DAY' THEN a.revenue ELSE 0 END) AS prev_revenue,
        SUM(CASE WHEN a.activity_date = d.snapshot_date - INTERVAL '1 DAY' THEN a.session_count ELSE 0 END) AS prev_session
    FROM date_spine d
    LEFT JOIN "03_user_daily_activity" a 
      ON d.user_id = a.user_id 
     AND a.activity_date BETWEEN d.snapshot_date - INTERVAL '6 DAY' AND d.snapshot_date
    GROUP BY d.user_id, d.snapshot_date
),
non_additive_rolling AS (
    SELECT
        d.user_id,
        d.snapshot_date,
        COUNT(DISTINCT e.product_id) AS product_diversity,
        COUNT(DISTINCT e.category_code) AS category_diversity,
        COUNT(DISTINCT e.brand) AS brand_diversity,
        COUNT(DISTINCT e.device) AS unique_device_count,
        COUNT(DISTINCT e.channel) AS unique_channel_count,
        STDDEV(e.price) AS price_diversity
    FROM date_spine d
    LEFT JOIN "events" e 
      ON d.user_id = e.user_id 
     AND CAST(e.event_time AS DATE) BETWEEN d.snapshot_date - INTERVAL '6 DAY' AND d.snapshot_date
    GROUP BY d.user_id, d.snapshot_date
),
stability_entropy_prep AS (
    SELECT 
        d.user_id,
        d.snapshot_date,
        -SUM(COALESCE((cat.cnt / NULLIF(cat.total_cnt, 0)) * LN(cat.cnt / NULLIF(cat.total_cnt, 0)), 0)) AS category_entropy,
        -SUM(COALESCE((brd.cnt / NULLIF(brd.total_cnt, 0)) * LN(brd.cnt / NULLIF(brd.total_cnt, 0)), 0)) AS brand_entropy,
        MAX(brd.cnt) / NULLIF(SUM(brd.cnt), 0) AS brand_stability,
        MAX(cat.cnt) / NULLIF(SUM(cat.cnt), 0) AS category_stability,
        MAX(cat.purch_cnt) / NULLIF(SUM(cat.purch_cnt), 0) AS purchase_concentration_ratio
    FROM date_spine d
    LEFT JOIN (
        SELECT 
            user_id,
            CAST(event_time AS DATE) AS act_date,
            category_code,
            COUNT(*) AS cnt,
            COUNT(*) FILTER(event_type = 'purchase') AS purch_cnt,
            SUM(COUNT(*)) OVER(PARTITION BY user_id, CAST(event_time AS DATE)) AS total_cnt
        FROM "events"
        WHERE category_code IS NOT NULL
        GROUP BY user_id, CAST(event_time AS DATE), category_code
    ) cat ON d.user_id = cat.user_id AND cat.act_date BETWEEN d.snapshot_date - INTERVAL '6 DAY' AND d.snapshot_date
    LEFT JOIN (
        SELECT 
            user_id,
            CAST(event_time AS DATE) AS act_date,
            brand,
            COUNT(*) AS cnt,
            SUM(COUNT(*)) OVER(PARTITION BY user_id, CAST(event_time AS DATE)) AS total_cnt
        FROM "events"
        WHERE brand IS NOT NULL
        GROUP BY user_id, CAST(event_time AS DATE), brand
    ) brd ON d.user_id = brd.user_id AND brd.act_date BETWEEN d.snapshot_date - INTERVAL '6 DAY' AND d.snapshot_date
    GROUP BY d.user_id, d.snapshot_date
),
-- ====================================================================
-- 🌟 [추가] 동적 분모(Dynamic Denominator) 사전 연산 CTE
-- ====================================================================
dynamic_denominator AS (
    SELECT 
        r.user_id,
        r.snapshot_date,
        -- 가입 후 경과 일수 계산 (0일 차 방지를 위해 최소 2.0 보장, 최대 7.0 제한)
        GREATEST(LEAST(EPOCH(CAST(r.snapshot_date AS TIMESTAMP) - l.first_activity_date) / 86400, 7.0), 2.0) AS effective_days
    FROM additive_rolling r
    -- 05번의 최초 활동일 정보를 조인하여 가입 경과 일수를 알아냅니다.
    LEFT JOIN (
        SELECT user_id, MIN(event_time) AS first_activity_date 
        FROM "events" 
        GROUP BY user_id
    ) l ON r.user_id = l.user_id
)
SELECT
    r.user_id,
    r.snapshot_date,
    
    -- Original Features (Additive)
    r.rolling_event_count,
    r.rolling_session_count,
    r.rolling_view_count,
    r.rolling_cart_count,
    r.rolling_purchase_count,
    r.active_days,
    r.last_activity_date,
    r.last_purchase_date,
    r.rolling_revenue,
    r.rolling_sum_viewed_revenue,
    -- r.avg_viewed_price,
    -- r.avg_purchased_price,
    r.max_purchase_price,
    r.weekend_count,
    
    -- Original Features (Non-additive)
    n.product_diversity AS product_diversity_count,
    n.category_diversity AS category_diversity_count,
    n.brand_diversity AS brand_diversity_count,
    n.unique_device_count,
    n.unique_channel_count,
    
    -- ====================================================================
    -- 🌟 [수정] 동적 분모(effective_days)를 일괄 적용한 Derived Features
    -- ====================================================================
    (r.rolling_event_count / d.effective_days) AS event_frequency,
    (r.rolling_session_count / d.effective_days) AS session_frequency,
    (r.rolling_purchase_count / d.effective_days) AS purchase_frequency,
    (r.rolling_cart_count / d.effective_days) AS cart_frequency,
    
    EPOCH(CAST(r.snapshot_date AS TIMESTAMP) - CAST(r.last_activity_date AS TIMESTAMP)) / 86400 AS days_since_last_activity,
    EPOCH(CAST(r.snapshot_date AS TIMESTAMP) - CAST(r.last_purchase_date AS TIMESTAMP)) / 86400 AS days_since_last_purchase,
    COALESCE(s.category_entropy, 0) AS category_entropy,
    COALESCE(s.brand_entropy, 0) AS brand_entropy,
    COALESCE(n.price_diversity, 0) AS price_diversity,

    -- weighted average order value (wAOV) 계산 시에도 동적 분모 활용
    CASE WHEN r.rolling_purchase_count > 0 THEN r.rolling_sum_viewed_revenue / NULLIF(r.rolling_view_count, 0) ELSE 0 END AS rolling_avg_viewed_price,
    CASE WHEN r.rolling_purchase_count > 0 THEN r.rolling_revenue / NULLIF(r.rolling_purchase_count, 0) ELSE 0 END AS rolling_average_revenue, -- [추가] 동적

    
    -- Velocity (가속도 계산 시에도 동적 평균치 활용으로 왜곡 최소화) : clamping 2days ~ 7days
    r.today_event_count - (r.rolling_event_count / d.effective_days) AS activity_acceleration,
    r.today_purchase_count - (r.rolling_purchase_count / d.effective_days) AS purchase_acceleration,
    CASE WHEN r.prev_revenue > 0 THEN (r.today_revenue - r.prev_revenue) / nullif(r.prev_revenue, 0) ELSE 0 END AS revenue_growth_rate,
    CASE WHEN r.prev_session > 0 THEN (r.today_session - r.prev_session) / nullif(r.prev_session, 0) ELSE 0 END AS session_growth_rate,
    
    -- Persistence & Value / Context
    CASE WHEN n.product_diversity > 0 THEN CAST(r.rolling_view_count AS DOUBLE) / nullif(n.product_diversity, 0) ELSE 0 END AS product_repeat_rate,
    COALESCE(s.brand_stability, 0) AS brand_stability,
    COALESCE(s.category_stability, 0) AS category_stability,
    COALESCE(s.purchase_concentration_ratio, 0) AS purchase_concentration_ratio,
    CASE WHEN r.rolling_purchase_count > 0 THEN r.rolling_revenue / NULLIF(r.rolling_purchase_count, 0) ELSE 0 END AS rolling_aov,
    CASE WHEN r.active_days > 0 THEN CAST(r.weekend_count AS DOUBLE) / nullif(r.active_days, 0) ELSE 0 END AS weekend_ratio
FROM additive_rolling r
LEFT JOIN non_additive_rolling n ON r.user_id = n.user_id AND r.snapshot_date = n.snapshot_date
LEFT JOIN stability_entropy_prep s ON r.user_id = s.user_id AND r.snapshot_date = s.snapshot_date
LEFT JOIN dynamic_denominator d ON r.user_id = d.user_id AND r.snapshot_date = d.snapshot_date -- [조인 추가]
ORDER BY r.snapshot_date, r.user_id;


CREATE OR REPLACE TABLE "05_user_lifetime_snapshot" AS
WITH date_spine AS (
    SELECT DISTINCT user_id, activity_date AS snapshot_date
    FROM "03_user_daily_activity"
),
lifetime_base AS (
    SELECT
        d.user_id,
        d.snapshot_date,
        -- Original Features
        MIN(e.event_time) AS first_activity_date,
        MIN(e.event_time) FILTER(e.event_type = 'purchase') AS first_purchase_date,
        MAX(e.event_time) AS last_activity_date,
        MAX(e.event_time) FILTER(e.event_type = 'purchase') AS last_purchase_date,
        COUNT(*) FILTER(e.event_type = 'purchase') AS lifetime_purchase_count,
        SUM(e.price) FILTER(e.event_type = 'purchase') AS lifetime_revenue,
        COUNT(DISTINCT e.brand) AS lifetime_brand_diversity,
        COUNT(DISTINCT e.category_code) AS lifetime_category_diversity
    FROM date_spine d
    LEFT JOIN "events" e 
      ON d.user_id = e.user_id 
     AND CAST(e.event_time AS DATE) <= d.snapshot_date
    GROUP BY d.user_id, d.snapshot_date
)
SELECT
    user_id,
    snapshot_date,
    
    -- Original Features
    first_activity_date,
    first_purchase_date,
    last_activity_date,
    last_purchase_date,
    lifetime_purchase_count,
    COALESCE(lifetime_revenue, 0) AS lifetime_revenue,
    lifetime_brand_diversity,
    lifetime_category_diversity,
    
    -- Derived Features
    CASE 
        -- Account Age Days 구하기 (초를 일수로 나눔)
        WHEN first_activity_date IS NOT NULL THEN EPOCH(CAST(snapshot_date AS TIMESTAMP) - first_activity_date) / 86400
        ELSE 0 
    END AS account_age_days,
    CASE 
        WHEN lifetime_purchase_count > 0 AND first_activity_date IS NOT NULL 
        THEN CAST(lifetime_purchase_count AS DOUBLE) / NULLIF(EPOCH(CAST(snapshot_date AS TIMESTAMP) - first_activity_date) / 86400, 0)
        ELSE 0 
    END AS lifetime_purchase_frequency,
    EPOCH(CAST(snapshot_date AS TIMESTAMP) - last_activity_date) / 86400 AS days_since_last_activity,
    EPOCH(CAST(snapshot_date AS TIMESTAMP) - last_purchase_date) / 86400 AS days_since_last_purchase,
    CASE 
        WHEN lifetime_purchase_count > 0 THEN COALESCE(lifetime_revenue, 0) / nullif(lifetime_purchase_count, 0) 
        ELSE 0 
    END AS lifetime_aov,
    CASE WHEN lifetime_purchase_count > 0 THEN 1 ELSE 0 END AS buyer_flag
FROM lifetime_base
ORDER BY snapshot_date, user_id;

-- 06 preference

CREATE OR REPLACE TABLE "07_user_feature_snapshot" AS
SELECT
    -- ====================================================================
    -- Primary Keys (Grain: User x Snapshot Date)
    -- ====================================================================
    COALESCE(r.user_id, l.user_id) AS user_id,
    COALESCE(r.snapshot_date, l.snapshot_date) AS snapshot_date,

    -- ====================================================================
    -- 1. Rolling Original Features (from 04_user_rolling_metrics)
    -- ====================================================================
    r.rolling_event_count,
    r.rolling_session_count,
    r.rolling_view_count,          -- [복구] 누락 지표
    r.rolling_cart_count,          -- [복구] 누락 지표
    r.rolling_purchase_count,
    r.active_days,
    r.last_activity_date AS rolling_last_activity_date,
    r.last_purchase_date AS rolling_last_purchase_date, -- [복구] 누락 지표
    r.product_diversity_count AS rolling_product_diversity,
    r.category_diversity_count AS rolling_category_diversity, -- [복구] 누락 지표
    r.brand_diversity_count AS rolling_brand_diversity,       -- [복구] 누락 지표
    r.rolling_revenue,
    r.unique_device_count AS rolling_unique_device_count,
    r.unique_channel_count AS rolling_unique_channel_count,                 -- [복구] 누락 지표

    -- ====================================================================
    -- 2. Rolling Derived Features (from 04_user_rolling_metrics)
    -- ====================================================================
    r.event_frequency AS rolling_event_frequency,
    r.session_frequency AS rolling_session_frequency,         -- [복구] 누락 지표
    r.purchase_frequency AS rolling_purchase_frequency,
    r.cart_frequency AS rolling_cart_frequency,               -- [복구] 누락 지표
    r.days_since_last_activity AS rolling_days_since_last_activity,
    r.days_since_last_purchase AS rolling_days_since_last_purchase,
    r.activity_acceleration,
    r.purchase_acceleration,
    r.brand_stability,
    r.product_repeat_rate AS rolling_product_repeat_rate,
    r.rolling_aov,
    r.weekend_ratio AS rolling_weekend_ratio,

    -- ====================================================================
    -- 3. Lifetime Original Features (from 05_user_lifetime_snapshot)
    -- ====================================================================
    l.first_activity_date AS lifetime_first_activity_date,
    l.first_purchase_date AS lifetime_first_purchase_date,   -- [복구] 누락 지표
    l.last_activity_date AS lifetime_last_activity_date,
    l.last_purchase_date AS lifetime_last_purchase_date,
    l.lifetime_revenue,
    l.lifetime_purchase_count,
    l.lifetime_brand_diversity,
    l.lifetime_category_diversity,

    -- ====================================================================
    -- 4. Lifetime Derived Features (from 05_user_lifetime_snapshot)
    -- ====================================================================
    l.lifetime_purchase_frequency,
    l.account_age_days AS lifetime_account_age_days,
    l.days_since_last_activity AS lifetime_days_since_last_activity, -- [복구] 누락 지표
    l.days_since_last_purchase AS lifetime_days_since_last_purchase,
    l.lifetime_aov,
    l.buyer_flag AS lifetime_buyer_flag -- 1 or 0 UTINYINT

FROM "05_user_lifetime_snapshot" l
LEFT JOIN "04_user_rolling_metrics" r 
  ON l.user_id = r.user_id 
 AND l.snapshot_date = r.snapshot_date
ORDER BY snapshot_date, user_id;


CREATE OR REPLACE TABLE "08_user_state_snapshot" AS
WITH state_rules AS (
    SELECT
        user_id,
        snapshot_date,
        
        -- ====================================================================
        -- 1. Funnel State Rule
        -- ====================================================================
        CASE 
            WHEN lifetime_buyer_flag = 0 AND rolling_purchase_frequency = 0 AND lifetime_account_age_days <= 3 
                THEN 'New Visitor'
            WHEN rolling_cart_frequency > 0 AND rolling_purchase_frequency = 0 
                THEN 'Engaged'
            WHEN rolling_purchase_frequency > 0 AND rolling_purchase_frequency < 0.2
                THEN 'Activated'
            WHEN rolling_purchase_frequency >= 0.2 AND rolling_purchase_frequency < 0.5
                THEN 'Repeated'
            WHEN rolling_revenue >= 500000 AND rolling_purchase_frequency >= 0.5 -- 임계값(Threshold) 예시 적용
                THEN 'Expanded'
            ELSE 'Engaged' -- Default Fallback
        END AS funnel_state,

        -- ====================================================================
        -- 2. Momentum State Rule
        -- ====================================================================
        CASE 
            WHEN activity_acceleration > 5.0 THEN 'Surging'
            WHEN activity_acceleration < -5.0 OR rolling_days_since_last_activity > 7 THEN 'Chilling'
            ELSE 'Stable'
        END AS momentum_state,

        -- ====================================================================
        -- 3. Browsing Style Rule
        -- ====================================================================
        CASE 
            -- Deep Diver: 높은 세션 깊이 + 낮은 상품 다양성
            WHEN rolling_event_count / NULLIF(active_days, 0) >= 10 AND rolling_product_diversity <= 3 
                THEN 'Deep Diver'
            -- Broad Scanner: 높은 상품 다양성 + 낮은 세션 깊이
            WHEN rolling_product_diversity >= 10 AND rolling_event_count / NULLIF(active_days, 0) < 5 
                THEN 'Broad Scanner'
            -- High Efficiency Buyer: 구매 빈도는 높으나 탐색 깊이는 낮음
            WHEN rolling_purchase_frequency >= 0.2 AND rolling_event_count / NULLIF(active_days, 0) < 3 
                THEN 'High Efficiency Buyer'
            -- Window Shopper: 탐색 활동은 있으나 구매 없음
            WHEN rolling_event_count > 0 AND rolling_purchase_count = 0 
                THEN 'Window Shopper'
            ELSE 'Regular Explorer'
        END AS browsing_state,

        -- ====================================================================
        -- 4. Customer Value Rule
        -- ====================================================================
        CASE 
            -- Champions: 높은 매출 + 높은 빈도 + 높은 최근성
            WHEN rolling_revenue >= 1000000 AND rolling_purchase_frequency >= 0.5 AND rolling_days_since_last_activity <= 3 
                THEN 'Champions'
            -- High Value: 높은 매출
            WHEN rolling_revenue >= 500000 
                THEN 'High Value'
            -- Promising: 구매 이력이 존재하고 가입한 지 얼마 안 됨
            WHEN lifetime_buyer_flag = 1 AND lifetime_account_age_days <= 30 
                THEN 'Promising'
            -- At Risk: 기존 고가치 유저였으나 최근 활동 없음
            WHEN lifetime_revenue >= 1000000 AND rolling_days_since_last_activity > 14 
                THEN 'At Risk'
            ELSE 'Low Value'
        END AS value_state,

        -- ====================================================================
        -- 5. Context State Rule (04_user_rolling_metrics 등의 raw 속성 및 주말비율 매핑)
        -- ====================================================================
        CASE 
            WHEN rolling_weekend_ratio >= 0.7 THEN 'Weekend Shopper'
            -- (기본 예시 규칙)
            ELSE 'Regular Pattern'
        END AS context_state,

        'v1.0' AS state_version -- 규칙 버전 관리

    FROM "07_user_feature_snapshot"
)
SELECT
    user_id,
    snapshot_date,
    funnel_state,
    momentum_state,
    browsing_state,
    value_state,
    context_state,
    state_version,
    CURRENT_TIMESTAMP AS created_at
FROM state_rules
ORDER BY snapshot_date, user_id;