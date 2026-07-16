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
        -- 🌟 [시간대별 이벤트 카운트 추가]
        COUNT(*) FILTER(EXTRACT(hour FROM event_time) IN (23, 0, 1, 2, 3)) AS night_owl_count,
        COUNT(*) FILTER(EXTRACT(hour FROM event_time) IN (4, 5, 6, 7)) AS early_bird_count,
        COUNT(*) FILTER(EXTRACT(hour FROM event_time) IN (11, 12, 13)) AS lunch_peak_count,
        COUNT(*) FILTER(EXTRACT(hour FROM event_time) IN (18, 19, 20, 21, 22)) AS evening_peak_count,
        -- 일반 낮 활동형은 전체 event_count에서 위 4개 시간대 이벤트를 제외한 나머지 시간대 이벤트로 정의
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
    e.night_owl_count,
    e.early_bird_count,
    e.lunch_peak_count,
    e.evening_peak_count,
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

        SUM(a.night_owl_count) AS rolling_night_owl_count,
        SUM(a.early_bird_count) AS rolling_early_bird_count,
        SUM(a.lunch_peak_count) AS rolling_lunch_peak_count,
        SUM(a.evening_peak_count) AS rolling_evening_peak_count,
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
        GREATEST(
            LEAST(
                (r.snapshot_date::DATE - l.first_activity_date::DATE), 
                7
            ), 
            2
        )::INTEGER AS effective_days
    FROM additive_rolling r
    -- 05번의 최초 활동일 정보를 조인하여 가입 경과 일수를 알아냅니다.
    LEFT JOIN (
        SELECT user_id, MIN(CAST(event_time AS DATE)) AS first_activity_date 
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
    r.rolling_night_owl_count,
    r.rolling_early_bird_count,
    r.rolling_lunch_peak_count,
    r.rolling_evening_peak_count,
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
    (r.rolling_event_count / CAST(d.effective_days AS DOUBLE)) AS event_frequency,
    (r.rolling_session_count / CAST(d.effective_days AS DOUBLE)) AS session_frequency,
    (r.rolling_purchase_count / CAST(d.effective_days AS DOUBLE)) AS purchase_frequency,
    (r.rolling_cart_count / CAST(d.effective_days AS DOUBLE)) AS cart_frequency,
    
    -- 🌟 [DuckDB 연산 교정] DATE 타입간 뺄셈으로 형변환 오류 차단 (정수 일수 반환)
    (r.snapshot_date::DATE - r.last_activity_date::DATE) AS days_since_last_activity,
    (r.snapshot_date::DATE - r.last_purchase_date::DATE) AS days_since_last_purchase,

    COALESCE(s.category_entropy, 0) AS category_entropy,
    COALESCE(s.brand_entropy, 0) AS brand_entropy,
    COALESCE(n.price_diversity, 0) AS price_diversity,

    -- weighted average order value (wAOV) 계산 시에도 동적 분모 활용
    CASE WHEN r.rolling_view_count > 0 THEN r.rolling_sum_viewed_revenue / NULLIF(r.rolling_view_count, 0) ELSE 0 END AS rolling_avg_viewed_price,
    CASE WHEN r.rolling_purchase_count > 0 THEN r.rolling_revenue / NULLIF(r.rolling_purchase_count, 0) ELSE 0 END AS rolling_average_revenue, -- [추가] 동적

    
    -- Velocity (가속도 계산 시에도 동적 평균치 활용으로 왜곡 최소화) : clamping 2days ~ 7days
    -- 🌟 [가속도 누수 보정 및 쉼표 구문 수정 완료]
    CASE 
        WHEN d.effective_days > 1 THEN 
            r.today_event_count - ((r.rolling_event_count - r.today_event_count) / CAST(d.effective_days - 1 AS DOUBLE)
            )
        ELSE 0 
    END AS activity_acceleration,
    
    -- 🌟 [구매 가속도 누수 정밀 수정]
    CASE 
        WHEN d.effective_days > 1 THEN 
            r.today_purchase_count - ((r.rolling_purchase_count - r.today_purchase_count) / CAST(d.effective_days - 1 AS DOUBLE))
        ELSE 0 
    END AS purchase_acceleration,
    CASE WHEN r.prev_revenue > 0 THEN (r.today_revenue - r.prev_revenue) / nullif(r.prev_revenue, 0) ELSE 0 END AS revenue_growth_rate,
    CASE WHEN r.prev_session > 0 THEN (r.today_session - r.prev_session) / nullif(r.prev_session, 0) ELSE 0 END AS session_growth_rate,
    
    -- Persistence & Value / Context
    CASE WHEN n.product_diversity > 0 THEN CAST(r.rolling_view_count AS DOUBLE) / nullif(n.product_diversity, 0) ELSE 0 END AS product_repeat_rate,
    COALESCE(s.brand_stability, 0) AS brand_stability,
    COALESCE(s.category_stability, 0) AS category_stability,
    COALESCE(s.purchase_concentration_ratio, 0) AS purchase_concentration_ratio,
    CASE WHEN r.rolling_purchase_count > 0 THEN r.rolling_revenue / NULLIF(r.rolling_purchase_count, 0) ELSE 0 END AS rolling_aov,

    -- 🌟 [롤링 기간 내 시간대별 활동 비율 계산]
    CASE WHEN r.rolling_event_count > 0 THEN CAST(r.rolling_night_owl_count AS DOUBLE) / r.rolling_event_count ELSE 0 END AS night_owl_ratio,
    CASE WHEN r.rolling_event_count > 0 THEN CAST(r.rolling_early_bird_count AS DOUBLE) / r.rolling_event_count ELSE 0 END AS early_bird_ratio,
    CASE WHEN r.rolling_event_count > 0 THEN CAST(r.rolling_lunch_peak_count AS DOUBLE) / r.rolling_event_count ELSE 0 END AS lunch_peak_ratio,
    CASE WHEN r.rolling_event_count > 0 THEN CAST(r.rolling_evening_peak_count AS DOUBLE) / r.rolling_event_count ELSE 0 END AS evening_peak_ratio,
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
        -- Original Features ; CAST DATE
        MIN(CAST(e.event_time AS DATE)) AS first_activity_date,
        MIN(CAST(e.event_time AS DATE)) FILTER(e.event_type = 'purchase') AS first_purchase_date,
        MAX(CAST(e.event_time AS DATE)) AS last_activity_date,
        MAX(CAST(e.event_time AS DATE)) FILTER(e.event_type = 'purchase') AS last_purchase_date,
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
    
 -- Derived Features (🌟 DuckDB 특화 정수 연산 적용)
    CASE 
        WHEN first_activity_date IS NOT NULL THEN (snapshot_date::DATE - first_activity_date::DATE)
        ELSE 0 
    END AS account_age_days,
    CASE 
        WHEN lifetime_purchase_count > 0 AND first_activity_date IS NOT NULL 
        THEN CAST(lifetime_purchase_count AS DOUBLE) / NULLIF((snapshot_date::DATE - first_activity_date::DATE), 0)
        ELSE 0 
    END AS lifetime_purchase_frequency,
    
    (snapshot_date::DATE - last_activity_date::DATE) AS days_since_last_activity,
    (snapshot_date::DATE - last_purchase_date::DATE) AS days_since_last_purchase,

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
    r.night_owl_ratio,
    r.early_bird_ratio,
    r.lunch_peak_ratio,
    r.evening_peak_ratio,
    r.weekend_ratio,

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
            WHEN lifetime_buyer_flag = 0 AND lifetime_account_age_days <= 3 
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
            WHEN CAST(rolling_event_count AS DOUBLE)/ NULLIF(active_days, 0) >= 10 AND rolling_product_diversity <= 3 
                THEN 'Deep Diver'
            -- Broad Scanner: 높은 상품 다양성 + 낮은 세션 깊이
            WHEN rolling_product_diversity >= 10 AND CAST(rolling_event_count AS DOUBLE) / NULLIF(active_days, 0) < 5 
                THEN 'Broad Scanner'
            -- High Efficiency Buyer: 구매 빈도는 높으나 탐색 깊이는 낮음
            WHEN rolling_purchase_frequency >= 0.2 AND CAST(rolling_event_count AS DOUBLE) / NULLIF(active_days, 0) < 3 
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
        -- 5. Context State Rule & Time Activity State (시간대별 라이프스타일 정의)
        -- ====================================================================
        CASE 
            WHEN weekend_ratio >= 0.7 THEN 'Weekend Shopper'
            ELSE 'Weekday Regular'
        END AS weekday_state,

        -- 🌟 [신규 시간대 유형 추가] 가장 높은 비중을 차지하는 시간대를 유저의 핵심 유형으로 매핑
        CASE
            -- 이벤트가 아예 없는 유저는 미분류
            WHEN rolling_event_count = 0 THEN 'Inactive'
            
            -- 각 시간대 비율 중 가장 큰 값을 찾아 매핑 (기준점 예시: 최소 30% 이상일 때 등 임계치 부여도 가능)
            WHEN night_owl_ratio >= GREATEST(early_bird_ratio, lunch_peak_ratio, evening_peak_ratio, (1.0 - night_owl_ratio - early_bird_ratio - lunch_peak_ratio - evening_peak_ratio))
                THEN 'Night Owl'
            WHEN early_bird_ratio >= GREATEST(night_owl_ratio, lunch_peak_ratio, evening_peak_ratio, (1.0 - night_owl_ratio - early_bird_ratio - lunch_peak_ratio - evening_peak_ratio))
                THEN 'Early Bird'
            WHEN lunch_peak_ratio >= GREATEST(night_owl_ratio, early_bird_ratio, evening_peak_ratio, (1.0 - night_owl_ratio - early_bird_ratio - lunch_peak_ratio - evening_peak_ratio))
                THEN 'Lunch Peak'
            WHEN evening_peak_ratio >= GREATEST(night_owl_ratio, early_bird_ratio, lunch_peak_ratio, (1.0 - night_owl_ratio - early_bird_ratio - lunch_peak_ratio - evening_peak_ratio))
                THEN 'Evening Peak'
            ELSE 'Daytime Active'
        END AS time_activity_state,
        
    -- ====================================================================
        -- 1. 라이프사이클 단계 (Account Age + Purchase Frequency 결합)
        -- ====================================================================
        CASE 
            WHEN lifetime_buyer_flag = 0 AND lifetime_account_age_days <= 3 
                THEN 'Newbie (Under 3d)'
            WHEN lifetime_buyer_flag = 1 AND lifetime_purchase_count >= 5 AND lifetime_purchase_frequency >= 0.2
                THEN 'Loyal VIP'
            WHEN lifetime_buyer_flag = 1 AND lifetime_purchase_count = 1 
                THEN 'One-Time Buyer'
            ELSE 'Regular User'
        END AS lifecycle_state,

        -- ====================================================================
        -- 2. 정교한 이탈 위험도 (Recency + Value 결합)
        -- ====================================================================
        CASE 
            -- 평소 구매 기여가 컸던 VIP가 최근 구매를 멈춘 지 오래된 경우 (최우선 감지)
            WHEN lifetime_revenue >= 500000 AND lifetime_days_since_last_purchase > 7 
                THEN 'VIP At-Risk'
            -- 구매 이력은 있으나 최근 활동과 구매 모두 끊긴 유저
            WHEN lifetime_buyer_flag = 1 AND lifetime_days_since_last_purchase > 21 
                THEN 'Churned Buyer'
            -- 단순 탐색 유저가 7일 이상 방문하지 않은 경우
            WHEN lifetime_buyer_flag = 0 AND lifetime_days_since_last_activity > 7 
                THEN 'Inactive Visitor'
            ELSE 'Active'
        END AS churn_risk_state,

        -- ====================================================================
        -- 3. 쇼핑 퍼소나 (Diversity, Repeat Rate, Device/Channel 결합)
        -- ====================================================================
        CASE 
            -- 한두 개 상품만 미친 듯이 반복 조회하는 경우 (구매 직전 장바구니 리타겟팅 대상)
            WHEN rolling_product_repeat_rate >= 3.0 AND rolling_purchase_count = 0 
                THEN 'High-Intent Ponderer'
            -- 브랜드나 카테고리 다양성이 매우 높은 경우 (다양한 구경을 즐김)
            WHEN rolling_brand_diversity >= 5 OR rolling_category_diversity >= 3 
                THEN 'Brand Explorer'
            -- 특정 단일 브랜드 집중도가 매우 높은 경우 (충성 고객)
            WHEN brand_stability >= 0.8 AND rolling_event_count > 5 
                THEN 'Brand Loyalist'
            -- 채널/디바이스를 다양하게 교차 사용하는 유저
            WHEN rolling_unique_device_count >= 2 OR rolling_unique_channel_count >= 2 
                THEN 'Cross-Platform User'
            ELSE 'Standard Shopper'
        END AS shopping_persona,

        -- ====================================================================
        -- 4. 구매력 및 거래 성향 (Rolling AOV + Lifetime AOV 결합)
        -- ====================================================================
        CASE 
            -- 최근 평균 구매 단가가 누적 평균보다 크게 올라간 유저 (업셀링 징후)
            WHEN rolling_aov > lifetime_aov AND rolling_purchase_count > 0 
                THEN 'Up-Trending Spender'
            -- 평소 1회 구매 시 고액을 결제하는 유저
            WHEN lifetime_aov >= 150000 
                THEN 'High-Value/Bulk Buyer'
            -- 구매 빈도는 높으나 단가는 낮은 유저
            WHEN lifetime_purchase_frequency >= 0.1 AND lifetime_aov < 30000 
                THEN 'Frequent Small Spender'
            ELSE 'Average Spender'
        END AS transaction_value_state,
        

        'v1.1' AS state_version -- 규칙 버전 관리

    FROM "07_user_feature_snapshot"
)
SELECT
    user_id,
    snapshot_date,
    -- v1.0
    funnel_state,
    momentum_state,
    browsing_state,
    value_state,
    weekday_state,
    -- v1.1
    lifecycle_state,
    churn_risk_state,
    shopping_persona,
    transaction_value_state,
    state_version,
    CURRENT_TIMESTAMP AS created_at
FROM state_rules
ORDER BY snapshot_date, user_id;