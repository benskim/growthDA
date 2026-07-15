Feature Space는 두 개의 축으로 정의된다.
1. Aggregation Level (집계 단위)
Event
    ↓
Session
    ↓
User
2. Aggregation Scope (집계 범위)
Rolling Window
Lifetime

## feature space의 level과 scope.

| Aggregation Level | Rolling              | Lifetime              |
| ----------------- | -------------------- | --------------------- |
| Event             | Raw Event            | -                     |
| Session           | Session Feature      | (거의 없음)           |
| User              | Rolling User Feature | Lifetime User Feature, first_seen |


# Matrix 1. Feature Catalog

State Engine는 **User Snapshot**을 입력으로 받아 State를 생성한다.

Feature는 다음과 같은 계층 구조를 갖는다.

```text
Raw Event   Raw Event
    │           │
    │           ▼
    │        Session Feature
    │           │
    ▼           ▼
User Rolling Feature
    │
    ├── Current Behavior
    │
    ▼
User Lifetime Feature
    │
    └── Historical Behavior
```

---

# 1. Event Feature (Raw Event)

가장 작은 단위의 이벤트 로그이다.

| Group | Feature | Type | Description |
|--------|---------|------|-------------|
| Event | event_time | TIMESTAMP | 이벤트 발생 시각 |
| Event | event_type | STRING | view / cart / purchase / remove_from_cart |
| User | user_id | STRING | 사용자 ID |
| Session | session_id | STRING | 세션 ID |
| Product | product_id | STRING | 상품 ID |
| Product | category_id | STRING | 카테고리 |
| Product | brand | STRING | 브랜드 |
| Product | price | DOUBLE | 상품 가격 |
| Context | device | STRING | Device |
| Context | channel | STRING | 유입 채널 |

---

# 2. Session Feature

> Aggregation Level = Session

세션 하나의 행동 특성을 표현한다.

| Axis | Feature | DuckDB SQL |
|------|---------|------------|
| Intensity | Session Duration | `DATEDIFF('second', MIN(event_time), MAX(event_time))` |
| Intensity | Session Event Count | `COUNT(*)` |
| Intensity | Session View Count | `COUNT(*) FILTER(event_type='view')` |
| Intensity | Session Cart Count | `COUNT(*) FILTER(event_type='cart')` |
| Intensity | Session Purchase Count | `COUNT(*) FILTER(event_type='purchase')` |
| Diversity | Product Diversity | `COUNT(DISTINCT product_id)` |
| Diversity | Brand Diversity | `COUNT(DISTINCT brand)` |
| Diversity | Category Diversity | `COUNT(DISTINCT category_id)` |
| Persistence | Product Repeat Rate | `COUNT(*)::DOUBLE / COUNT(DISTINCT product_id)` |
| Persistence | Brand Stability | `MAX(cnt) / SUM(cnt)` *(brand frequency 기준)* |
| Value | Session Revenue | `SUM(price) FILTER(event_type='purchase')` |
| Value | Session AOV | `SUM(price) FILTER(event_type='purchase') / NULLIF(COUNT(*) FILTER(event_type='purchase'),0)` |
| Preference | Preferred Brand | `ARG_MAX(brand, cnt)` |
| Preference | Preferred Category | `ARG_MAX(category_id, cnt)` |
| Preference | Avg Viewed Price | `AVG(price) FILTER(event_type='view')` |
| Context | Active Hour | `MODE(EXTRACT(hour FROM event_time))` |

---

# 3. User Rolling Feature

> Aggregation Level = User
>
> Aggregation Scope = Rolling Window

최근 행동을 표현하는 Feature이다.

## 3.1 Intensity

| Feature | DuckDB SQL | Recommended Window |
|---------|------------|--------------------|
| Event Count | `COUNT(*)` | 7d |
| View Count | `COUNT(*) FILTER(event_type='view')` | 7d |
| Cart Count | `COUNT(*) FILTER(event_type='cart')` | 7d |
| Purchase Count | `COUNT(*) FILTER(event_type='purchase')` | 14d |
| Session Count | `COUNT(DISTINCT session_id)` | 7d |
| Avg Session Duration | `AVG(session_duration)` | 7d |
| Avg Session Depth | `AVG(session_event_count)` | 7d |

---

## 3.2 Diversity

| Feature | DuckDB SQL | Recommended Window |
|---------|------------|--------------------|
| Product Diversity | `COUNT(DISTINCT product_id)` | 7d |
| Category Diversity | `COUNT(DISTINCT category_id)` | 7d |
| Brand Diversity | `COUNT(DISTINCT brand)` | 14d |
| Category Entropy | `-SUM(p * LN(p))` | 7d |
| Brand Entropy | `-SUM(p * LN(p))` | 14d |
| Price Diversity | `STDDEV(price)` | 14d |

> `p = category_count / total_count`

---

## 3.3 Persistence

| Feature | DuckDB SQL | Recommended Window |
|---------|------------|--------------------|
| Product Repeat Rate | `COUNT(*)::DOUBLE / COUNT(DISTINCT product_id)` | 14d |
| Brand Stability | `MAX(brand_cnt) / SUM(brand_cnt)` | 30d |
| Category Stability | `MAX(category_cnt) / SUM(category_cnt)` | 30d |
| Interest Persistence | `MAX(category_cnt) / SUM(category_cnt)` | 30d |
| Purchase Concentration Ratio | `MAX(category_purchase_cnt)/SUM(category_purchase_cnt)` | 30d |

---

## 3.4 Value

| Feature | DuckDB SQL | Recommended Window |
|---------|------------|--------------------|
| Revenue | `SUM(price) FILTER(event_type='purchase')` | 30d |
| Purchase Frequency | `COUNT(*) FILTER(event_type='purchase')` | 30d |
| Average Order Value (AOV) | `SUM(price)/COUNT(*) FILTER(event_type='purchase')` | 30d |
| Max Purchase Price | `MAX(price) FILTER(event_type='purchase')` | 30d |
| Avg Viewed Price | `AVG(price) FILTER(event_type='view')` | 14d |
| Avg Purchased Price | `AVG(price) FILTER(event_type='purchase')` | 30d |

---

## 3.5 Preference

| Feature | DuckDB SQL | Recommended Window |
|---------|------------|--------------------|
| Preferred Brand | `ARG_MAX(brand, cnt)` | 30d |
| Preferred Category | `ARG_MAX(category_id, cnt)` | 30d |
| Preferred Price Tier | `ARG_MAX(price_bucket, cnt)` | 30d |

---

## 3.6 Context

| Feature | DuckDB SQL | Recommended Window |
|---------|------------|--------------------|
| Active Hour | `MODE(EXTRACT(hour FROM event_time))` | 14d |
| Weekend Ratio | `SUM(is_weekend)/COUNT(*)` | 14d |
| mobile Ratio | `mobile_cnt / total_cnt` | 14d |
| Channel Ratio | `channel_cnt / total_cnt` | 30d |

---

# 4. User Lifetime Feature

> Aggregation Level = User
>
> Aggregation Scope = Lifetime : 지금은 30일이지만 total + incremental 로 변경

누적 이력(Historical Profile)을 표현한다.

## 4.1 Lifecycle

| Feature | DuckDB SQL |
|---------|------------|
| Account Age (Tenure) | `DATE_DIFF('day', MIN(event_time), snapshot_date)` |
| First Activity Date | `MIN(event_time)` |
| First Purchase Date | `MIN(event_time) FILTER(event_type='purchase')` |
| Last Activity Date | `MAX(event_time)` |
| Last Purchase Date | `MAX(event_time) FILTER(event_type='purchase')` |
| Days Since Last Activity | `DATE_DIFF('day', MAX(event_time), snapshot_date)` |
| Days Since Last Purchase | `DATE_DIFF('day', MAX(event_time) FILTER(event_type='purchase'), snapshot_date)` |

---

## 4.2 Lifetime Value

| Feature | DuckDB SQL |
|---------|------------|
| Lifetime Purchase Count | `COUNT(*) FILTER(event_type='purchase')` |
| Lifetime Revenue | `SUM(price) FILTER(event_type='purchase')` |
| Lifetime AOV | `SUM(price) / COUNT(*) FILTER(event_type='purchase')` |
| Lifetime Brand Diversity | `COUNT(DISTINCT brand)` |
| Lifetime Category Diversity | `COUNT(DISTINCT category_id)` |
| Buyer Flag | `MAX(CASE WHEN event_type='purchase' THEN 1 ELSE 0 END)` |

---

# Feature Summary

| Layer | Scope | Purpose |
|--------|-------|---------|
| Event | Raw | 원시 이벤트 로그 |
| Session | Per Session | 방문 행동 분석 |
| User Rolling | Recent (7/14/30d) | 현재 행동(State) |
| User Lifetime | Lifetime | 장기 이력(Profile) |

---

# State Engine

```text
                 Event
                   │
                   ▼
          Session Feature
                   │
                   ▼
      User Rolling Feature
      (Current Behavior)
                   │
                   ├────────────┐
                   ▼            │
             User State         │
                                │
      User Lifetime Feature     │
      (Historical Profile)      │
                   │            │
                   └──────┬─────┘
                          ▼
                 Final User State
                          │
                          ▼
                  State Transition
```

## Design Principles

- **Event**는 원시 데이터이며 집계하지 않는다.
- **Session**은 방문 단위의 행동을 표현하는 중간 계층이다.
- **User Rolling**은 최근 행동(Current Behavior)을 나타내며 State 생성의 핵심 입력이다.
- **User Lifetime**은 장기 이력을 나타내며 Rolling Feature를 보완하는 역할을 한다.
- **State Transition**은 별도의 Feature를 저장하지 않고, 서로 다른 시점의 User Snapshot을 비교하여 계산한다.

---

# State Engine에서의 역할

각 State는 이 Feature Catalog를 조합하여 정의됩니다.

| State              | 주요 Feature                                                             |
| ------------------ | ---------------------------------------------------------------------- |
| **New Visitor**    | Account Age, Purchase Frequency, Cart Frequency                        |
| **Engaged**        | Cart Frequency, Product Repeat Rate, Category Entropy                  |
| **Activated**      | Purchase Frequency = 1                                                 |
| **Repeated**       | Purchase Frequency ≥ 2, Revenue, Interest Persistence                  |
| **Expanded**       | Revenue, Purchase Concentration Ratio, AOV                             |
| **Surging**        | Event Frequency, Session Frequency, Cart Frequency (최근 Snapshot 대비 증가) |
| **Chilling**       | Last Activity Days, Event Frequency 감소                                 |
| **Deep Diver**     | Avg Session Depth ↑, Product Diversity ↓                               |
| **Broad Scanner**  | Product Diversity ↑, Session Depth ↓                                   |
| **Brand Loyalist** | Brand Stability ↑                                                      |
| **Brand Nomad**    | Brand Entropy ↑                                                        |
| **VIP**            | Revenue, Purchase Frequency, AOV                                       |
| **Promising**      | Account Age, Purchase Frequency, Event Frequency                       |

---

## 마지막으로 추천하는 수정

현재 카탈로그에는 **Frequency와 Count가 모두 포함**되어 있습니다. 하지만 `Frequency = Count / Window Days`이므로 정보가 중복됩니다.

실무에서는 다음처럼 역할을 분리하는 것을 권장합니다.

* **Count**: 절대 활동량(예: 구매 8회, 조회 120회)
* **Frequency**: 기간이 다른 Snapshot 간 비교를 위한 정규화 지표(예: 하루 평균 구매 0.57회)

만약 **모든 Snapshot이 동일한 14일 Window**에서 계산된다면 `Frequency`는 `Count`의 상수배이므로 저장하지 않고 필요 시 계산해도 됩니다. 반대로 **7일, 14일, 30일 Window를 함께 운영**하거나 사용자별 관측 기간이 다를 수 있다면 `Frequency`를 별도 Feature로 유지하는 것이 유용합니다. 이렇게 하면 Feature Catalog의 중복을 줄이면서도 확장성을 확보할 수 있습니다.
