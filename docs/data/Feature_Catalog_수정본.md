# Feature Catalog (오류 수정본)

> 본 문서는 원본 Feature Catalog에서 발견된 6가지 계산식 오류/불일치를 수정한 버전입니다.
> 수정된 부분은 **🔧 수정** 표시와 함께 원본 대비 변경 사유를 병기했습니다.

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

| Axis        | Feature             | Source  | Method     | Formula                                                                     |
| ----------- | ------------------- | ------- | ---------- | ---------------------------------------------------------------------------- |
| Intensity   | Session Duration    | Session | Difference | `End Time - Start Time`                                                     |
| Intensity   | Session Depth       | Session | Identity   | `Session Event Count`                                                       |
| Persistence | Product Repeat Rate | Session | Ratio      | `Session Event Count / NULLIF(Product Diversity, 0)` 🔧 분모 0 방어           |
| Value       | Session AOV         | Session | Ratio      | `Session Revenue / NULLIF(Session Purchase Count, 0)` 🔧 분모 0 방어          |

---

# 2. User Daily Feature Catalog

**Primary Key**

```
(user_id, activity_date)
```

---

## 2.1 Original Features

| Axis      | Feature                     | Source  | Method         | DuckDB SQL                                            |
| --------- | ---------------------------- | ------- | -------------- | ------------------------------------------------------ |
| Intensity | Event Count                  | events  | COUNT          | `COUNT(*)`                                            |
| Intensity | Session Count                | session | COUNT          | `COUNT(*)`                                            |
| Intensity | View Count                   | events  | COUNT          | `COUNT(*) FILTER(event_type='view')`                  |
| Intensity | Cart Count                   | events  | COUNT          | `COUNT(*) FILTER(event_type='cart')`                  |
| Intensity | Purchase Count               | events  | COUNT          | `COUNT(*) FILTER(event_type='purchase')`              |
| Frequency | Active Day                   | events  | Constant       | `1`                                                    |
| Recency   | Last Activity Date           | events  | MAX            | `MAX(DATE(event_time))`                                |
| Recency   | Last Purchase Date           | events  | MAX            | `MAX(DATE(event_time)) FILTER(event_type='purchase')`  |
| Diversity | Product Diversity            | events  | COUNT DISTINCT | `COUNT(DISTINCT product_id)`                           |
| Diversity | Category Diversity           | events  | COUNT DISTINCT | `COUNT(DISTINCT category_id)`                          |
| Diversity | Brand Diversity              | events  | COUNT DISTINCT | `COUNT(DISTINCT brand)`                                |
| Value     | Revenue                       | events  | SUM            | `SUM(price) FILTER(event_type='purchase')`             |
| Value     | Avg Viewed Price              | events  | AVG            | `AVG(price) FILTER(event_type='view')`                 |
| Value     | Sum Viewed Price 🔧 신규       | events  | SUM            | `SUM(price) FILTER(event_type='view')` 🔧 Rolling 가중평균용 원본 추가 |
| Value     | Avg Purchased Price           | events  | AVG            | `AVG(price) FILTER(event_type='purchase')`             |
| Value     | Sum Purchased Price 🔧 신규    | events  | SUM            | `SUM(price) FILTER(event_type='purchase')` 🔧 Rolling 가중평균용 원본 추가 |
| Value     | Max Purchase Price            | events  | MAX            | `MAX(price) FILTER(event_type='purchase')`             |
| Context   | First Active Hour             | events  | MIN            | `MIN(EXTRACT(hour FROM event_time))`                   |
| Context   | Last Active Hour              | events  | MAX            | `MAX(EXTRACT(hour FROM event_time))`                   |
| Context   | Weekend Count                 | events  | SUM            | `SUM(is_weekend)`                                      |
| Context   | Device Count                  | events  | COUNT DISTINCT | `COUNT(DISTINCT device)`                               |
| Context   | Channel Count                 | events  | COUNT DISTINCT | `COUNT(DISTINCT channel)`                              |

> 🔧 **수정 사유 (이슈 #3 대응):** Rolling 단계에서 `Avg Viewed Price` / `Avg Purchased Price`를 정확한 가중평균으로 재계산할 수 있도록, User Daily 단계에 `SUM(price)` 원본(`Sum Viewed Price`, `Sum Purchased Price`)을 추가했습니다. `View Count`, `Purchase Count`는 기존 Intensity 지표를 그대로 재사용합니다.

---

## 2.2 Derived Features

| Axis      | Feature              | Source     | Method  | Formula                       |
| --------- | -------------------- | ---------- | ------- | ------------------------------ |
| Intensity | Avg Session Duration | session    | AVG     | `AVG(Session Duration)`         |
| Intensity | Avg Session Depth    | session    | AVG     | `AVG(Session Depth)`            |
| Diversity | Category Entropy     | events     | Entropy | `-Σ p ln(p)`                    |
| Diversity | Brand Entropy        | events     | Entropy | `-Σ p ln(p)`                    |
| Diversity | Price Diversity      | events     | Dispersion (STDDEV) 🔧 Method 명칭 명확화 | `STDDEV(price)` |
| Value     | Average Order Value  | User Daily | Ratio   | `Revenue / NULLIF(Purchase Count, 0)` 🔧 분모 0 방어 |
| Context   | Weekend Ratio        | User Daily | Ratio   | `Weekend Count / NULLIF(Event Count, 0)` 🔧 분모 0 방어 (그 날이 주말이면 1, 평일이면 0인 이진값) |

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

| Axis      | Feature                     | Source     | Method         | Formula                                    |
| --------- | ---------------------------- | ---------- | -------------- | -------------------------------------------- |
| Intensity | Rolling Event Count          | user_daily | SUM            | `SUM(Event Count)`                          |
| Intensity | Rolling Session Count        | user_daily | SUM            | `SUM(Session Count)`                        |
| Intensity | Rolling View Count           | user_daily | SUM            | `SUM(View Count)`                           |
| Intensity | Rolling Cart Count           | user_daily | SUM            | `SUM(Cart Count)`                           |
| Intensity | Rolling Purchase Count       | user_daily | SUM            | `SUM(Purchase Count)`                       |
| Frequency | Active Days                  | user_daily | SUM            | `SUM(Active Day)`                           |
| Recency   | Last Activity Date           | user_daily | MAX            | `MAX(Last Activity Date)`                   |
| Recency   | Last Purchase Date           | user_daily | MAX            | `MAX(Last Purchase Date)`                   |
| Diversity | Product Diversity            | events     | COUNT DISTINCT | `COUNT(DISTINCT product_id)`                |
| Diversity | Category Diversity           | events     | COUNT DISTINCT | `COUNT(DISTINCT category_id)`               |
| Diversity | Brand Diversity              | events     | COUNT DISTINCT | `COUNT(DISTINCT brand)`                     |
| Value     | Rolling Revenue              | user_daily | SUM            | `SUM(Revenue)`                              |
| Value     | Rolling Sum Viewed Price 🔧 신규 | user_daily | SUM       | `SUM(Sum Viewed Price)` 🔧 가중평균 계산용 |
| Value     | Rolling Sum Purchased Price 🔧 신규 | user_daily | SUM   | `SUM(Sum Purchased Price)` 🔧 가중평균 계산용 |
| Value     | Max Purchase Price            | user_daily | MAX            | `MAX(Max Purchase Price)`                   |
| Context   | Weekend Count                 | user_daily | SUM            | `SUM(Weekend Count)`                        |
| Context   | Device Count                  | events     | COUNT DISTINCT | `COUNT(DISTINCT device)`                    |
| Context   | Channel Count                 | events     | COUNT DISTINCT | `COUNT(DISTINCT channel)`                   |

> 🔧 **삭제:** 기존의 `Avg Viewed Price = AVG(Avg Viewed Price)`, `Avg Purchased Price = AVG(Avg Purchased Price)`는 mean-of-means 편향 문제(이슈 #3)로 제거하고, 아래 3.2 Derived Features에서 가중평균으로 재정의합니다.

---

## 3.2 Derived Features

| Axis        | Feature                      | Source     | Method     | Formula                                                                                     |
| ----------- | ----------------------------- | ---------- | ---------- | ---------------------------------------------------------------------------------------------- |
| Frequency   | Event Frequency               | Rolling    | Ratio      | `Rolling Event Count / Window Days`                                                            |
| Frequency   | Session Frequency             | Rolling    | Ratio      | `Rolling Session Count / Window Days`                                                          |
| Frequency   | Purchase Frequency            | Rolling    | Ratio      | `Rolling Purchase Count / Window Days`                                                         |
| Frequency   | Cart Frequency                 | Rolling    | Ratio      | `Rolling Cart Count / Window Days`                                                             |
| Recency     | Days Since Last Activity       | Rolling    | Difference | `Snapshot Date - Last Activity Date`                                                            |
| Recency     | Days Since Last Purchase       | Rolling    | Difference | `Snapshot Date - Last Purchase Date`                                                            |
| Diversity   | Category Entropy               | events     | Entropy    | `-Σ p ln(p)`                                                                                    |
| Diversity   | Brand Entropy                  | events     | Entropy    | `-Σ p ln(p)`                                                                                    |
| Diversity   | Price Diversity                 | events     | Dispersion (STDDEV) 🔧 Method 명칭 명확화 | `STDDEV(price)`                                                          |
| Value       | Rolling Avg Viewed Price 🔧 수정 | Rolling    | Weighted Ratio 🔧 | `Rolling Sum Viewed Price / NULLIF(Rolling View Count, 0)` 🔧 mean-of-means → 가중평균으로 수정 |
| Value       | Rolling Avg Purchased Price 🔧 수정 | Rolling | Weighted Ratio 🔧 | `Rolling Sum Purchased Price / NULLIF(Rolling Purchase Count, 0)` 🔧 mean-of-means → 가중평균으로 수정 |
| Velocity    | Activity Acceleration 🔧 수정   | user_daily | Difference | `Today Event Count - Rolling Avg(Event Count, 오늘 제외 이전 Window)` 🔧 데이터 누수 방지: 베이스라인에서 오늘 제외 |
| Velocity    | Purchase Acceleration 🔧 수정   | user_daily | Difference | `Today Purchase Count - Rolling Avg(Purchase Count, 오늘 제외 이전 Window)` 🔧 데이터 누수 방지: 베이스라인에서 오늘 제외 |
| Velocity    | Revenue Growth Rate            | user_daily | Growth     | `(Today Revenue - Previous Revenue) / NULLIF(Previous Revenue, 0)` 🔧 분모 0 방어              |
| Velocity    | Session Growth Rate            | user_daily | Growth     | `(Today Session - Previous Session) / NULLIF(Previous Session, 0)` 🔧 분모 0 방어              |
| Persistence | Product Repeat Rate 🔧 수정     | Rolling    | Ratio      | `Rolling Event Count / NULLIF(Product Diversity, 0)` 🔧 Session 레벨과 정의 일치 (View→Event Count로 통일), 분모 0 방어 |
| Persistence | Brand Stability                | events     | Stability 🔧 Method 명칭 정정 | `Max Brand Count / NULLIF(Total Brand Count, 0)`                                    |
| Persistence | Category Stability             | events     | Stability 🔧 Method 명칭 정정 | `Max Category Count / NULLIF(Total Category Count, 0)`                             |
| Persistence | Purchase Concentration Ratio   | events     | Concentration 🔧 Method 명칭 정정 | `Max Category Purchase / NULLIF(Total Purchase, 0)`                            |
| Value       | Rolling AOV                    | Rolling    | Ratio      | `Rolling Revenue / NULLIF(Rolling Purchase Count, 0)` 🔧 분모 0 방어                          |
| Context     | Weekend Ratio 🔧 수정          | Rolling    | Ratio      | `Weekend Count / NULLIF(Rolling Event Count, 0)` 🔧 분모를 Active Days에서 Rolling Event Count로 변경 (User Daily와 동일한 0~1 비율 의미 유지) |

---

# 4. Lifetime Feature Catalog

**Primary Key**

```
(user_id, snapshot_date)
```

Lifetime Feature는 사용자의 누적 이력을 표현한다.

---

## 4.1 Original Features

| Axis      | Feature                     | Source | Method         | DuckDB SQL                                             |
| --------- | ----------------------------- | ------ | -------------- | --------------------------------------------------------- |
| Recency   | First Activity Date 🔧 수정   | events | MIN            | `MIN(DATE(event_time))` 🔧 DATE 캐스팅 추가 (Rolling/Daily와 타입 통일) |
| Recency   | First Purchase Date 🔧 수정   | events | MIN            | `MIN(DATE(event_time)) FILTER(event_type='purchase')` 🔧 DATE 캐스팅 추가 |
| Recency   | Last Activity Date 🔧 수정    | events | MAX            | `MAX(DATE(event_time))` 🔧 DATE 캐스팅 추가                |
| Recency   | Last Purchase Date 🔧 수정    | events | MAX            | `MAX(DATE(event_time)) FILTER(event_type='purchase')` 🔧 DATE 캐스팅 추가 |
| Value     | Lifetime Purchase Count       | events | COUNT          | `COUNT(*) FILTER(event_type='purchase')`                  |
| Value     | Lifetime Revenue              | events | SUM            | `SUM(price) FILTER(event_type='purchase')`                 |
| Diversity | Lifetime Brand Diversity       | events | COUNT DISTINCT | `COUNT(DISTINCT brand)`                                    |
| Diversity | Lifetime Category Diversity    | events | COUNT DISTINCT | `COUNT(DISTINCT category_id)`                              |

> 🔧 **수정 사유 (이슈 #5 대응):** 원본은 `MIN(event_time)` / `MAX(event_time)`처럼 타임스탬프를 그대로 사용해, 이후 `Account Age`, `Days Since Last Activity/Purchase` 계산 시 Snapshot Date(DATE)와의 뺄셈에서 시:분:초가 섞인 interval이 나올 위험이 있었습니다. User Daily/Rolling과 동일하게 `DATE(event_time)`으로 캐스팅하여 일(day) 단위 정수 차이가 나오도록 통일했습니다.

---

## 4.2 Derived Features

| Axis      | Feature                     | Source   | Method     | Formula                                                       |
| --------- | ----------------------------- | -------- | ---------- | ------------------------------------------------------------------ |
| Frequency | Lifetime Purchase Frequency    | Lifetime | Ratio      | `Lifetime Purchase Count / NULLIF(Account Age Days, 0)` 🔧 분모 0 방어 |
| Recency   | Account Age (Tenure)           | Lifetime | Difference | `Snapshot Date - First Activity Date`                              |
| Recency   | Days Since Last Activity       | Lifetime | Difference | `Snapshot Date - Last Activity Date`                               |
| Recency   | Days Since Last Purchase       | Lifetime | Difference | `Snapshot Date - Last Purchase Date`                               |
| Value     | Lifetime AOV                   | Lifetime | Ratio      | `Lifetime Revenue / NULLIF(Lifetime Purchase Count, 0)` 🔧 분모 0 방어 |
| Value     | Buyer Flag                     | Lifetime | Boolean    | `Lifetime Purchase Count > 0`                                       |

---

# Feature Engineering Principles

* Rolling Feature는 **User Daily Feature를 기반으로 생성**하는 것을 원칙으로 한다.
* 단, **COUNT DISTINCT** 계열(Product Diversity, Brand Diversity, Category Diversity, Device Count, Channel Count)은 합산이 불가능한 **Semi-additive Metric**이므로 Rolling 계산 시 **Raw Event를 다시 조회**한다.
* Original Feature는 **COUNT, COUNT DISTINCT, SUM, AVG, MIN, MAX**만 사용한다.
* Derived Feature는 Original Feature를 이용한 **Ratio, Difference, Growth, Entropy, Stability, Concentration, Weighted Ratio(🔧 신규 추가)** 등의 계산으로 정의한다.
  * 🔧 **Weighted Ratio 추가 사유:** 일별 평균값을 상위 계층에서 다시 평균 내는 mean-of-means 방식은 건수 가중치가 반영되지 않아 편향이 생기므로, `SUM(daily sum) / SUM(daily count)` 형태의 가중평균 계산 유형을 별도로 명시한다.
* Frequency는 단순 Count가 아니라 반드시 **Count ÷ Window Days**로 정의한다.
* 🔧 **분모 0 방어 원칙 (신규 추가):** 모든 Ratio/Growth 계열 Derived Feature는 분모가 0이 될 수 있는 경우 `NULLIF(분모, 0)` 등으로 방어하여 division-by-zero 오류 및 무한대 값을 방지한다.
* 🔧 **Velocity 계산 원칙 (신규 추가):** Acceleration 계열(오늘 값 - Rolling 평균) 계산 시, 베이스라인이 되는 Rolling 평균은 오늘 데이터를 포함하지 않은 이전 Window로 계산하여 데이터 누수를 방지한다.
* Preference와 Lifecycle은 Behavioral Axis가 아니며, Feature로부터 계산되는 **State 또는 Semantic 정보**이므로 본 Catalog에는 포함하지 않는다.

---

# 수정 이력 요약 (Changelog)

| # | 대상 Feature | 원본 정의 | 수정 후 정의 | 사유 |
|---|---|---|---|---|
| 1 | Rolling `Product Repeat Rate` | `Rolling View Count / Product Diversity` | `Rolling Event Count / NULLIF(Product Diversity, 0)` | Session 레벨(전체 이벤트 기준) 정의와 불일치 → 통일 |
| 2 | Rolling `Weekend Ratio` | `Weekend Count / Active Days` | `Weekend Count / NULLIF(Rolling Event Count, 0)` | 분자(이벤트 수)를 분모(일수)로 나눠 0~1 비율이 아니게 되던 문제 수정 |
| 3 | Rolling `Avg Viewed/Purchased Price` | `AVG(Avg Viewed Price)` (mean of means) | `Rolling Sum Price / NULLIF(Rolling Count, 0)` (가중평균) | 건수 가중치 미반영으로 인한 통계적 편향 제거, User Daily에 SUM 원본 추가 |
| 4 | Velocity `Activity/Purchase Acceleration` | 오늘 포함 Rolling Avg와 비교 | 오늘 제외 이전 Window Avg와 비교 | 베이스라인에 오늘 값이 섞여 변화량이 희석되는 데이터 누수 방지 |
| 5 | Lifetime `First/Last Activity/Purchase Date` | `MIN(event_time)` / `MAX(event_time)` (timestamp) | `MIN(DATE(event_time))` / `MAX(DATE(event_time))` | 하위 계산(Account Age 등)에서 날짜 타입 불일치로 인한 오차 방지 |
| 6 | `Brand/Category Stability`, `Purchase Concentration Ratio` | Method: "Ratio" | Method: "Stability" / "Concentration" | 원칙 문서의 계산 유형 분류와 실제 태깅 불일치 수정 |
| 7 | 전체 Ratio/Growth 계열 | 분모 0 방어 로직 없음 | `NULLIF(분모, 0)` 적용 | Division-by-zero / 무한대 값 방지 |
