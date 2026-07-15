# metric 소개

## level
| Level             | Feature                                                              |
| ----------------- |-------------------------------------------------------------------------- |
| **Event-level**   | Raw Events                                                 |
| **Session-level** | Session Length, Views/Session, Products/Session, Bounce Rate, Conversion Rate |
| **User-level**    | Intensity, Diversity, Value, Persistence, Preference            |
| **Rolling-level** | ΔIntensity, Velocity, Revenue Growth, Switching                 |

## behavior axis
| Axis            | 질문              | 대표Feature                        |
| --------------- | --------------- |------------------------------------- |
| **Intensity**   | 얼마나 많이 행동하는가?   | Event Count, Event Frequency, Session Count, Session Frequency, View Count |
| **Diversity**   | 얼마나 다양하게 탐색하는가? | Category Entropy, Product Diversity, Brand Diversity                       |
| **Velocity**    | 얼마나 빠르게 변하는가?   | Activity Acceleration, Purchase Intent Acceleration                        |
| **Persistence** | 얼마나 일관되게 행동하는가? | Repeat Rate, Interest Persistence, Brand Stability                         |
| **Value**       | 얼마나 가치 있는 고객인가? | Revenue, Purchase Frequency, AOV, LTV                                      |
| **Recency**     | 얼마나 최근에 활동했는가?  | Last Activity Days, Last Purchase Days                                     |
| **Preference**  | 무엇을 선호하는가?      | Preferred Brand, Category, Price Tier                                      |
| **Context**     | 언제·어디서 행동하는가?   | Hour, Weekday, Device , Channel                                             |

### axis-metric-sql
| Axis        | Metric                 | 정의          | DuckDB SQL                                                                                 |
| ----------- | ---------------------- | ----------- | ------------------------------------------------------------------------------------------ |
| Intensity   | Event Frequency        | 일평균 이벤트 수   | `COUNT(*) / 14.0`                                                                          |
| Intensity   | View Frequency         | 일평균 조회수     | `COUNT(*) FILTER(event_type='view') / 14.0`                                                |
| Intensity   | Cart Frequency         | 일평균 장바구니 수  | `COUNT(*) FILTER(event_type='cart') / 14.0`                                                |
| Intensity   | Session Frequency      | 일평균 세션 수    | `COUNT(DISTINCT user_session)/14.0`                                                        |
| Diversity   | Product Diversity      | 조회 상품 수     | `COUNT(DISTINCT product_id)`                                                               |
| Diversity   | Brand Diversity        | 조회 브랜드 수    | `COUNT(DISTINCT brand)`                                                                    |
| Diversity   | Category Diversity     | 조회 카테고리 수   | `COUNT(DISTINCT category_code)`                                                            |
| Diversity   | Category Entropy       | 카테고리 다양성    | `-SUM(p*LN(p))` *(CTE 필요)*                                                                 |
| Velocity    | Activity Acceleration  | 최근 활동 증가    | `(recent_events-previous_events)/3.0`                                                      |
| Velocity    | Purchase Velocity      | 일평균 구매수     | `COUNT(*) FILTER(event_type='purchase')/14.0`                                              |
| Velocity    | Time to First Purchase | 가입→첫 구매     | `DATE_DIFF('day', MIN(user_first_seen), MIN(purchase_time))`                               |
| Persistence | Product Repeat Rate    | 동일 상품 반복 조회 | `COUNT(*)::DOUBLE / COUNT(DISTINCT product_id)`                                            |
| Persistence | Brand Stability        | 브랜드 집중도     | `MAX(brand_cnt)/SUM(brand_cnt)` *(브랜드별 집계 후)*                                              |
| Persistence | Category Stability     | 카테고리 집중도    | `MAX(category_cnt)/SUM(category_cnt)`                                                      |
| Value       | Revenue                | 총 매출        | `SUM(price)`                                                                               |
| Value       | Purchase Frequency     | 구매 횟수       | `COUNT(*) FILTER(event_type='purchase')`                                                   |
| Value       | AOV                    | 평균 주문금액     | `SUM(price)/COUNT(*) FILTER(event_type='purchase')`                                        |
| Value       | Max Purchase           | 최대 구매금액     | `MAX(price)`                                                                               |
| Recency     | Last Activity Days     | 마지막 활동 경과일  | `DATE_DIFF('day', MAX(event_time), CURRENT_DATE)`                                          |
| Recency     | Last Purchase Days     | 마지막 구매 경과일  | `DATE_DIFF('day', MAX(CASE WHEN event_type='purchase' THEN event_time END), CURRENT_DATE)` |
| Preference  | Preferred Brand        | 최다 조회 브랜드   | `ARG_MAX(brand, cnt)` *(브랜드별 집계 후)*                                                        |
| Preference  | Preferred Category     | 최다 조회 카테고리  | `ARG_MAX(category_code, cnt)`                                                              |
| Preference  | Avg Viewed Price       | 평균 조회 가격    | `AVG(price) FILTER(event_type='view')`                                                     |
| Context     | Active Hour            | 주요 활동 시간    | `MODE(EXTRACT(hour FROM event_time))`                                                      |
| Context     | Weekend Ratio          | 주말 활동 비율    | `SUM(CASE WHEN DAYOFWEEK(event_time) IN (0,6) THEN 1 ELSE 0 END)/COUNT(*)`                 |
| Context     | Device Ratio           | 디바이스별 비율    | `COUNT(*) FILTER(device='mobile')/COUNT(*)`                                                |
| Context     | Channel Ratio          | 유입채널 비율     | `COUNT(*) FILTER(channel='organic')/COUNT(*)`                                              |


---

# Matrix 1. Feature Space (DuckDB SQL)

## Intensity
Metric            | DuckDB SQL                                |
| ----------------- | ----------------------------------------- |
| Event Count       | `COUNT(*)`                                |
| Event Frequency   | `COUNT(*) / 7.0`                         |
| Session Count     | `COUNT(DISTINCT user_session)`            |
| Session Frequency | `COUNT(DISTINCT user_session)/7.0`       |
| View Frequency    | `COUNT(*) FILTER(event_type='view')/7.0` |
| Cart Frequency    | `COUNT(*) FILTER(event_type='cart')/7.0` |

---

## Diversity

| Metric             | DuckDB SQL                      |
| ------------------ | ------------------------------- |
| Product Diversity  | `COUNT(DISTINCT product_id)`    |
| Brand Diversity    | `COUNT(DISTINCT brand)`         |
| Category Diversity | `COUNT(DISTINCT category_code)` |

Entropy는 조금 깁니다.

```sql
WITH dist AS (
SELECT
    user_id,
    category_code,
    COUNT(*)::DOUBLE /
    SUM(COUNT(*)) OVER(PARTITION BY user_id) AS p
FROM events
GROUP BY user_id, category_code
)

SELECT
user_id,
-SUM(p*LN(p)) AS category_entropy
FROM dist
GROUP BY user_id;
```

---

## Velocity

최근 3일과 이전 3일 비교

```sql
WITH activity AS (

SELECT
user_id,

SUM(
CASE
WHEN event_time>=CURRENT_DATE-INTERVAL '3 day'
THEN 1 ELSE 0
END
) recent,

SUM(
CASE
WHEN event_time BETWEEN
CURRENT_DATE-INTERVAL '6 day'
AND CURRENT_DATE-INTERVAL '3 day'
THEN 1 ELSE 0
END
) previous

FROM events
GROUP BY user_id

)

SELECT *,
(recent-previous)/3.0 AS activity_acceleration
FROM activity;
```

---

## Persistence

Product Repeat Rate

```sql
COUNT(*)::DOUBLE /
COUNT(DISTINCT product_id)
```

Brand Stability

```sql
MAX(brand_cnt)/SUM(brand_cnt)
```

(brand_cnt는 브랜드별 COUNT)

---

## Value

| Metric             | DuckDB SQL                                          |
| ------------------ | --------------------------------------------------- |
| Revenue            | `SUM(price)`                                        |
| Purchase Frequency | `COUNT(*) FILTER(event_type='purchase')`            |
| AOV                | `SUM(price)/COUNT(*) FILTER(event_type='purchase')` |
| Max Purchase       | `MAX(price)`                                        |

---

## Recency

```sql
DATE_DIFF(
'day',
MAX(event_time),
CURRENT_DATE
)
```

구매 기준

```sql
DATE_DIFF(
'day',
MAX(CASE WHEN event_type='purchase' THEN event_time END),
CURRENT_DATE
)
```

---

## Preference

가장 많이 본 브랜드

```sql
ARG_MAX(brand, cnt)
```

DuckDB에서는

```sql
SELECT
user_id,
ARG_MAX(brand,cnt)
FROM (
SELECT
user_id,
brand,
COUNT(*) cnt
FROM events
GROUP BY user_id,brand
)
GROUP BY user_id;
```

평균 조회가격

```sql
AVG(price)
FILTER(event_type='view')
```

---

## Context

오전 비율

```sql
SUM(
CASE
WHEN EXTRACT(hour FROM event_time)
BETWEEN 6 AND 9
THEN 1 ELSE 0
END
)
/COUNT(*)
```

주말 비율

```sql
SUM(
CASE
WHEN DAYOFWEEK(event_time)
IN (0,6)
THEN 1 ELSE 0
END
)
/COUNT(*)
```

---

# 수학적 정의 + DuckDB 구현식

| Metric                | Mathematical Definition  | DuckDB SQL                                        |   |                              |
| --------------------- | ------------------------ | ------------------------------------------------- | - | ---------------------------- |
| Event Frequency       | (N_{event}/T_{obs})      | `COUNT(*)/7.0`                                   |   |                              |
| Product Diversity     | (                        | P                                                 | ) | `COUNT(DISTINCT product_id)` |
| Category Entropy      | (-\sum p_i\log p_i)      | CTE + `SUM(-p*LN(p))`                             |   |                              |
| Purchase Frequency    | (N_{purchase})           | `COUNT(*) FILTER(event_type='purchase')`          |   |                              |
| AOV                   | (Revenue/Orders)         | `SUM(price)/COUNT(*) FILTER(...)`                 |   |                              |
| Activity Acceleration | ((Recent-Past)/\Delta t) | CTE (최근 3일 vs 이전 3일)                              |   |                              |
| Brand Stability       | (\max(p_{brand}))        | `MAX(brand_cnt)/SUM(brand_cnt)`                   |   |                              |
| Last Activity Days    | (Today-last_activity)    | `DATE_DIFF('day', MAX(event_time), CURRENT_DATE)` |   |                              |

이 방식은 **이론적 정의**와 **재현 가능한 구현**을 동시에 제공하므로, 연구와 실무 모두에서 활용하기에 적합합니다.
