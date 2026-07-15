# Feature Catalog

본 문서는 **State Engine**의 입력이 되는 Feature를 정의한다.

Feature는 다음 네 개의 계층으로 구성된다.

```
Session Feature
        │
        ▼
User Daily Feature
        │
        ▼
Rolling Feature
        │
        ▼
Lifetime Feature
```

모든 Feature는 다음 원칙을 따른다.

* **Original Feature**

  * COUNT
  * COUNT DISTINCT
  * SUM
  * AVG
  * MIN
  * MAX
  * 이벤트를 직접 집계하여 생성되는 Feature

* **Derived Feature**

  * Original Feature를 이용하여 계산
  * Ratio
  * Difference
  * Growth
  * Entropy
  * Stability
  * Concentration
  * Time Difference

모든 Feature는 아래 **8개의 Behavioral Axis** 중 하나에 속한다.

| Axis        | Description    |
| ----------- | -------------- |
| Intensity   | 얼마나 많이 행동하는가   |
| Frequency   | 얼마나 자주 행동하는가   |
| Recency     | 얼마나 최근에 행동하는가  |
| Diversity   | 얼마나 다양하게 행동하는가 |
| Velocity    | 얼마나 빠르게 변화하는가  |
| Persistence | 얼마나 지속되는가      |
| Value       | 얼마나 소비하는가      |
| Context     | 언제/어디서 행동하는가   |

---

# 1. Session Feature Catalog

**Aggregation Level**

```
Session
```

Session은 User Daily Metric 생성을 위한 중간 계층이다.

---

## 1.1 Original Features

| Axis      | Feature                | Source | Method         | DuckDB SQL                                 |
| --------- | ---------------------- | ------ | -------------- | ------------------------------------------ |
| Intensity | Session Event Count    | events | COUNT          | `COUNT(*)`                                 |
| Intensity | Session View Count     | events | COUNT          | `COUNT(*) FILTER(event_type='view')`       |
| Intensity | Session Cart Count     | events | COUNT          | `COUNT(*) FILTER(event_type='cart')`       |
| Intensity | Session Purchase Count | events | COUNT          | `COUNT(*) FILTER(event_type='purchase')`   |
| Diversity | Product Diversity      | events | COUNT DISTINCT | `COUNT(DISTINCT product_id)`               |
| Diversity | Category Diversity     | events | COUNT DISTINCT | `COUNT(DISTINCT category_id)`              |
| Diversity | Brand Diversity        | events | COUNT DISTINCT | `COUNT(DISTINCT brand)`                    |
| Value     | Session Revenue        | events | SUM            | `SUM(price) FILTER(event_type='purchase')` |
| Context   | Session Start Time     | events | MIN            | `MIN(event_time)`                          |
| Context   | Session End Time       | events | MAX            | `MAX(event_time)`                          |
| Context   | Device                 | events | ANY_VALUE      | `ANY_VALUE(device)`                        |
| Context   | Channel                | events | ANY_VALUE      | `ANY_VALUE(channel)`                       |

---

## 1.2 Derived Features

| Axis        | Feature             | Source  | Method     | Formula                                    |
| ----------- | ------------------- | ------- | ---------- | ------------------------------------------ |
| Intensity   | Session Duration    | Session | Difference | `End Time - Start Time`                    |
| Intensity   | Session Depth       | Session | Identity   | `Session Event Count`                      |
| Persistence | Product Repeat Rate | Session | Ratio      | `Session Event Count / Product Diversity`  |
| Value       | Session AOV         | Session | Ratio      | `Session Revenue / Session Purchase Count` |

---

# 2. User Daily Feature Catalog

**Primary Key**

```
(user_id, activity_date)
```

---

## 2.1 Original Features

| Axis      | Feature             | Source  | Method         | DuckDB SQL                                            |
| --------- | ------------------- | ------- | -------------- | ----------------------------------------------------- |
| Intensity | Event Count         | events  | COUNT          | `COUNT(*)`                                            |
| Intensity | Session Count       | session | COUNT          | `COUNT(*)`                                            |
| Intensity | View Count          | events  | COUNT          | `COUNT(*) FILTER(event_type='view')`                  |
| Intensity | Cart Count          | events  | COUNT          | `COUNT(*) FILTER(event_type='cart')`                  |
| Intensity | Purchase Count      | events  | COUNT          | `COUNT(*) FILTER(event_type='purchase')`              |
| Frequency | Active Day          | events  | Constant       | `1`                                                   |
| Recency   | Last Activity Date  | events  | MAX            | `MAX(DATE(event_time))`                               |
| Recency   | Last Purchase Date  | events  | MAX            | `MAX(DATE(event_time)) FILTER(event_type='purchase')` |
| Diversity | Product Diversity   | events  | COUNT DISTINCT | `COUNT(DISTINCT product_id)`                          |
| Diversity | Category Diversity  | events  | COUNT DISTINCT | `COUNT(DISTINCT category_id)`                         |
| Diversity | Brand Diversity     | events  | COUNT DISTINCT | `COUNT(DISTINCT brand)`                               |
| Value     | Revenue             | events  | SUM            | `SUM(price) FILTER(event_type='purchase')`            |
| Value     | Avg Viewed Price    | events  | AVG            | `AVG(price) FILTER(event_type='view')`                |
| Value     | Avg Purchased Price | events  | AVG            | `AVG(price) FILTER(event_type='purchase')`            |
| Value     | Max Purchase Price  | events  | MAX            | `MAX(price) FILTER(event_type='purchase')`            |
| Context   | First Active Hour   | events  | MIN            | `MIN(EXTRACT(hour FROM event_time))`                  |
| Context   | Last Active Hour    | events  | MAX            | `MAX(EXTRACT(hour FROM event_time))`                  |
| Context   | Weekend Count       | events  | SUM            | `SUM(is_weekend)`                                     |
| Context   | Device Count        | events  | COUNT DISTINCT | `COUNT(DISTINCT device)`                              |
| Context   | Channel Count       | events  | COUNT DISTINCT | `COUNT(DISTINCT channel)`                             |

---

## 2.2 Derived Features

| Axis      | Feature              | Source     | Method  | Formula                       |
| --------- | -------------------- | ---------- | ------- | ----------------------------- |
| Intensity | Avg Session Duration | session    | AVG     | `AVG(Session Duration)`       |
| Intensity | Avg Session Depth    | session    | AVG     | `AVG(Session Depth)`          |
| Diversity | Category Entropy     | events     | Entropy | `-Σ p ln(p)`                  |
| Diversity | Brand Entropy        | events     | Entropy | `-Σ p ln(p)`                  |
| Diversity | Price Diversity      | events     | STDDEV  | `STDDEV(price)`               |
| Value     | Average Order Value  | User Daily | Ratio   | `Revenue / Purchase Count`    |
| Context   | Weekend Ratio        | User Daily | Ratio   | `Weekend Count / Event Count` |

---

# 3. Rolling Feature Catalog

**Primary Key**

```
(user_id, snapshot_date)
```

Rolling Window는 User Daily Feature를 기반으로 생성된다.

권장 Window

* 3 Days
* 7 Days

---

## 3.1 Original Features

> 원칙
>
> SUM / AVG / MIN / MAX 만 사용한다.
>
> **COUNT DISTINCT 계열은 Raw Event(events)를 다시 읽는다.**

| Axis      | Feature                | Source     | Method         | Formula                       |
| --------- | ---------------------- | ---------- | -------------- | ----------------------------- |
| Intensity | Rolling Event Count    | user_daily | SUM            | `SUM(Event Count)`            |
| Intensity | Rolling Session Count  | user_daily | SUM            | `SUM(Session Count)`          |
| Intensity | Rolling View Count     | user_daily | SUM            | `SUM(View Count)`             |
| Intensity | Rolling Cart Count     | user_daily | SUM            | `SUM(Cart Count)`             |
| Intensity | Rolling Purchase Count | user_daily | SUM            | `SUM(Purchase Count)`         |
| Frequency | Active Days            | user_daily | SUM            | `SUM(Active Day)`             |
| Recency   | Last Activity Date     | user_daily | MAX            | `MAX(Last Activity Date)`     |
| Recency   | Last Purchase Date     | user_daily | MAX            | `MAX(Last Purchase Date)`     |
| Diversity | Product Diversity      | events     | COUNT DISTINCT | `COUNT(DISTINCT product_id)`  |
| Diversity | Category Diversity     | events     | COUNT DISTINCT | `COUNT(DISTINCT category_id)` |
| Diversity | Brand Diversity        | events     | COUNT DISTINCT | `COUNT(DISTINCT brand)`       |
| Value     | Rolling Revenue        | user_daily | SUM            | `SUM(Revenue)`                |
| Value     | Avg Viewed Price       | user_daily | AVG            | `AVG(Avg Viewed Price)`       |
| Value     | Avg Purchased Price    | user_daily | AVG            | `AVG(Avg Purchased Price)`    |
| Value     | Max Purchase Price     | user_daily | MAX            | `MAX(Max Purchase Price)`     |
| Context   | Weekend Count          | user_daily | SUM            | `SUM(Weekend Count)`          |
| Context   | Device Count           | events     | COUNT DISTINCT | `COUNT(DISTINCT device)`      |
| Context   | Channel Count          | events     | COUNT DISTINCT | `COUNT(DISTINCT channel)`     |

---

## 3.2 Derived Features

| Axis        | Feature                      | Source     | Method     | Formula                                              |
| ----------- | ---------------------------- | ---------- | ---------- | ---------------------------------------------------- |
| Frequency   | Event Frequency              | Rolling    | Ratio      | `Rolling Event Count / Window Days`                  |
| Frequency   | Session Frequency            | Rolling    | Ratio      | `Rolling Session Count / Window Days`                |
| Frequency   | Purchase Frequency           | Rolling    | Ratio      | `Rolling Purchase Count / Window Days`               |
| Frequency   | Cart Frequency               | Rolling    | Ratio      | `Rolling Cart Count / Window Days`                   |
| Recency     | Days Since Last Activity     | Rolling    | Difference | `Snapshot Date - Last Activity Date`                 |
| Recency     | Days Since Last Purchase     | Rolling    | Difference | `Snapshot Date - Last Purchase Date`                 |
| Diversity   | Category Entropy             | events     | Entropy    | `-Σ p ln(p)`                                         |
| Diversity   | Brand Entropy                | events     | Entropy    | `-Σ p ln(p)`                                         |
| Diversity   | Price Diversity              | events     | STDDEV     | `STDDEV(price)`                                      |
| Velocity    | Activity Acceleration        | user_daily | Difference | `Today Event Count - Rolling Avg(Event Count)`       |
| Velocity    | Purchase Acceleration        | user_daily | Difference | `Today Purchase Count - Rolling Avg(Purchase Count)` |
| Velocity    | Revenue Growth Rate          | user_daily | Growth     | `(Today Revenue-Previous Revenue)/Previous Revenue`  |
| Velocity    | Session Growth Rate          | user_daily | Growth     | `(Today Session-Previous Session)/Previous Session`  |
| Persistence | Product Repeat Rate          | Rolling    | Ratio      | `Rolling View Count / Product Diversity`             |
| Persistence | Brand Stability              | events     | Ratio      | `Max Brand Count / Total Brand Count`                |
| Persistence | Category Stability           | events     | Ratio      | `Max Category Count / Total Category Count`          |
| Persistence | Purchase Concentration Ratio | events     | Ratio      | `Max Category Purchase / Total Purchase`             |
| Value       | Rolling AOV                  | Rolling    | Ratio      | `Rolling Revenue / Rolling Purchase Count`           |
| Context     | Weekend Ratio                | Rolling    | Ratio      | `Weekend Count / Active Days`                        |

---

# 4. Lifetime Feature Catalog

**Primary Key**

```
(user_id, snapshot_date)
```

Lifetime Feature는 사용자의 누적 이력을 표현한다.

---

## 4.1 Original Features

| Axis      | Feature                     | Source | Method         | DuckDB SQL                                      |
| --------- | --------------------------- | ------ | -------------- | ----------------------------------------------- |
| Recency   | First Activity Date         | events | MIN            | `MIN(event_time)`                               |
| Recency   | First Purchase Date         | events | MIN            | `MIN(event_time) FILTER(event_type='purchase')` |
| Recency   | Last Activity Date          | events | MAX            | `MAX(event_time)`                               |
| Recency   | Last Purchase Date          | events | MAX            | `MAX(event_time) FILTER(event_type='purchase')` |
| Value     | Lifetime Purchase Count     | events | COUNT          | `COUNT(*) FILTER(event_type='purchase')`        |
| Value     | Lifetime Revenue            | events | SUM            | `SUM(price) FILTER(event_type='purchase')`      |
| Diversity | Lifetime Brand Diversity    | events | COUNT DISTINCT | `COUNT(DISTINCT brand)`                         |
| Diversity | Lifetime Category Diversity | events | COUNT DISTINCT | `COUNT(DISTINCT category_id)`                   |

---

## 4.2 Derived Features

| Axis      | Feature                     | Source   | Method     | Formula                                      |
| --------- | --------------------------- | -------- | ---------- | -------------------------------------------- |
| Frequency | Lifetime Purchase Frequency | Lifetime | Ratio      | `Lifetime Purchase Count / Account Age Days` |
| Recency   | Account Age (Tenure)        | Lifetime | Difference | `Snapshot Date - First Activity Date`        |
| Recency   | Days Since Last Activity    | Lifetime | Difference | `Snapshot Date - Last Activity Date`         |
| Recency   | Days Since Last Purchase    | Lifetime | Difference | `Snapshot Date - Last Purchase Date`         |
| Value     | Lifetime AOV                | Lifetime | Ratio      | `Lifetime Revenue / Lifetime Purchase Count` |
| Value     | Buyer Flag                  | Lifetime | Boolean    | `Lifetime Purchase Count > 0`                |

---

# Feature Engineering Principles

* Rolling Feature는 **User Daily Feature를 기반으로 생성**하는 것을 원칙으로 한다.
* 단, **COUNT DISTINCT** 계열(Product Diversity, Brand Diversity, Category Diversity, Device Count, Channel Count)은 합산이 불가능한 **Semi-additive Metric**이므로 Rolling 계산 시 **Raw Event를 다시 조회**한다.
* Original Feature는 **COUNT, COUNT DISTINCT, SUM, AVG, MIN, MAX**만 사용한다.
* Derived Feature는 Original Feature를 이용한 **Ratio, Difference, Growth, Entropy, Stability, Concentration** 등의 계산으로 정의한다.
* Frequency는 단순 Count가 아니라 반드시 **Count ÷ Window Days**로 정의한다.
* Preference와 Lifecycle은 Behavioral Axis가 아니며, Feature로부터 계산되는 **State 또는 Semantic 정보**이므로 본 Catalog에는 포함하지 않는다.


--------
# 5. User Snapshot Catalog

**Primary Key**

```text
(user_id, snapshot_date)
```

User Snapshot은 State Engine의 입력이 되는 최종 Feature Vector이다.

새로운 Feature를 생성하지 않으며, Rolling Feature와 Lifetime Feature를 하나의 Snapshot으로 통합한다.

---

## 5.1 Snapshot Schema

| Group             | Source                 | Description      |
| ----------------- | ---------------------- | ---------------- |
| User              | -                      | user_id          |
| Snapshot          | -                      | snapshot_date    |
| Rolling Original  | user_rolling_original  | 최근 행동 원본 Feature |
| Rolling Derived   | user_rolling_derived   | 최근 행동 파생 Feature |
| Lifetime Original | user_lifetime_original | 누적 행동 원본 Feature |
| Lifetime Derived  | user_lifetime_derived  | 누적 행동 파생 Feature |

---

## 5.2 Feature Composition

### Rolling Original

| Axis      | Example Feature        |
| --------- | ---------------------- |
| Intensity | Rolling Event Count    |
| Intensity | Rolling Session Count  |
| Intensity | Rolling Purchase Count |
| Frequency | Active Days            |
| Recency   | Last Activity Date     |
| Diversity | Product Diversity      |
| Value     | Rolling Revenue        |
| Context   | Device Count           |

---

### Rolling Derived

| Axis        | Example Feature          |
| ----------- | ------------------------ |
| Frequency   | Purchase Frequency       |
| Frequency   | Event Frequency          |
| Recency     | Days Since Last Activity |
| Velocity    | Activity Acceleration    |
| Velocity    | Purchase Acceleration    |
| Persistence | Brand Stability          |
| Persistence | Product Repeat Rate      |
| Value       | Rolling AOV              |
| Context     | Weekend Ratio            |

---

### Lifetime Original

| Axis      | Example Feature             |
| --------- | --------------------------- |
| Recency   | First Activity Date         |
| Recency   | Last Activity Date          |
| Value     | Lifetime Revenue            |
| Value     | Lifetime Purchase Count     |
| Diversity | Lifetime Brand Diversity    |
| Diversity | Lifetime Category Diversity |

---

### Lifetime Derived

| Axis      | Example Feature             |
| --------- | --------------------------- |
| Frequency | Lifetime Purchase Frequency |
| Recency   | Account Age                 |
| Recency   | Days Since Last Purchase    |
| Value     | Lifetime AOV                |
| Value     | Buyer Flag                  |

---

## 5.3 Snapshot Construction

```text
user_snapshot
=
user_rolling_original
LEFT JOIN user_rolling_derived
LEFT JOIN user_lifetime_original
LEFT JOIN user_lifetime_derived
```

Join Key

```text
(user_id, snapshot_date)
```

---

## 5.4 Snapshot Characteristics

| Property            | Description                        |
| ------------------- | ---------------------------------- |
| Grain               | User × Snapshot Date               |
| Update Frequency    | Daily                              |
| Input               | Rolling Feature + Lifetime Feature |
| Output              | State Engine Input                 |
| Contains Label      | No                                 |
| Contains State      | No                                 |
| Contains Transition | No                                 |

---

## 5.5 State Engine Input

User Snapshot은 **State를 계산하기 위한 입력 Feature Vector**이다.

```text
Raw Event
      │
      ▼
Session Feature
      │
      ▼
User Daily Feature
      │
      ▼
Rolling Original
Rolling Derived
      │
      ▼
Lifetime Original
Lifetime Derived
      │
      ▼
───────────────
 User Snapshot
───────────────
      │
      ▼
 State Engine
      │
      ▼
 User State Snapshot
      │
      ▼
 State Transition
```

---

### Design Principles

* User Snapshot에서는 **새로운 Metric을 계산하지 않는다.**
* User Snapshot은 **Rolling Feature와 Lifetime Feature를 통합한 Feature Store**이다.
* 모든 Feature는 Snapshot Date 기준으로 정렬되며, 동일한 `(user_id, snapshot_date)`에서 하나의 Feature Vector를 구성한다.
* State는 User Snapshot으로부터 계산되며, Snapshot 자체에는 State(Label)를 저장하지 않는다.
* State Transition은 서로 다른 시점의 User Snapshot과 User State Snapshot을 비교하여 계산한다.

> **권장 사항:** `user_snapshot`은 가능한 한 **Wide Table(1행 = 1 User × 1 Snapshot Date)** 형태로 유지하는 것이 좋습니다. 이렇게 하면 CRM 규칙 엔진, ML Feature Store, 추천 시스템, State Engine이 모두 동일한 입력 테이블을 사용할 수 있어 운영과 확장성이 크게 향상됩니다.


---

앞선 분석에서 말씀드린 **중복 지표**는 데이터베이스상에 컬럼이 여러 개 중복되어 존재한다는 의미가 아니라, "카탈로그에서 정의한 8대 행동 축(Axis)을 기준으로 분류할 때, 한 지표가 여러 행동 축의 의미를 동시에 내포하고 있어 다중 매핑된 지표"를 의미합니다.

실제 중복 처리된 지표와 그 설계 배경은 다음과 같습니다.

---

## 🔍 다중 매핑된 중복 지표 (3가지)

행동 축 분류상 2개 이상의 영역에 걸쳐 있는 핵심 지표는 다음과 같습니다.

### 1. `lifetime_purchase_count` (누적 구매 횟수)

* **중복 매핑된 축:** **Intensity(행동 강도)** × **Value(고객 가치)**
* **이유:**
* **Intensity 측면:** 유저가 서비스 내에서 발생시킨 누적 행동의 총량(양적 볼륨)을 대변합니다.
* **Value 측면:** 전통적인 고객 가치 평가 모델(RFM)에서 Frequency(구매 빈도/횟수)이자 비즈니스 매출에 직접 기여한 거래 횟수를 의미하므로, 고객의 생애 가치(LTV)를 평가하는 핵심 가치 지표가 됩니다.



### 2. `active_days` (최근 활동 일수)

* **중복 매핑된 축:** **Intensity(행동 강도)** × **Frequency(행동 빈도)**
* **이유:**
* **Intensity 측면:** 단순히 며칠 동안 들어왔는가에 대한 양적인 '참여 규모'를 뜻합니다.
* **Frequency 측면:** 이 값을 기반으로 다른 파생 지표들(`rolling_purchase_frequency`, `rolling_event_frequency`)의 분모 역할을 수행하며, 방문 주기가 얼마나 잦은지 평가하는 기준점(주기성)이 됩니다.



### 3. `rolling_last_activity_date` / `lifetime_last_activity_date` (마지막 활동일)

* **중복 매핑된 축:** **Recency(최근성)** × **Momentum(최근 행동 변화/속도)**
* **이유:**
* **Recency 측면:** 마지막 활동 시점이 언제인가를 나타내는 순수 타임스탬프 정보입니다.
* **Momentum 측면:** 이 마지막 활동일로부터 오늘까지 며칠이 지났는지(`days_since_last_activity`)를 계산하게 하므로, 고객의 행동 속도가 감속(`Chilling`)하고 있는지 감지하는 동적 변화량의 원천 데이터가 됩니다.



---

## 🛠️ 왜 이렇게 중복(다중 매핑)이 발생하도록 설계했는가?

데이터를 물리적으로 중복 저장하는 것은 비효율적이지만, 지표의 다차원적 해석(Semantic Mapping)을 위해 축을 중복 정의하는 것은 매우 의도적이고 정교한 설계입니다.

### 1. 비즈니스 맥락에 따른 '해석의 다변화'

동일한 데이터값이라도 분석 목적에 따라 바라보는 관점(Axis)이 달라집니다.

* 예를 들어, 어떤 유저의 "구매 횟수 100회"는 단순히 앱을 많이 쓰는 강도(Intensity)로 볼 수도 있지만, 마케터에게는 이 고객이 최우수 등급인지를 판단하는 가치(Value)의 기준이 됩니다.

### 2. 다차원 상태 엔진(State Engine)으로의 매끄러운 연계

우리가 만든 State Engine은 5가지의 상태 축(`funnel_state`, `value_state` 등)을 가집니다.

* `lifetime_purchase_count` 같은 지표가 한 쪽에만 갇혀 있으면, 성장 퍼널 상태(Funnel State)를 계산할 때도 쓰고 고객 가치 상태(Customer Value)를 계산할 때도 써야 하는 상태 엔진이 이 지표를 유연하게 참조하기 어려워집니다.
* 행동 축을 열어두고 다중 매핑함으로써, 하나의 원천 지표가 다양한 상태 라벨을 정의하는 훌륭한 재료가 될 수 있도록 설계한 것입니다.