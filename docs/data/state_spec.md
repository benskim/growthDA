# State Engine Specification

State Engine는 **User Snapshot**을 입력으로 받아 사용자의 행동 상태(State)를 생성하고, 시간에 따른 상태 변화를 추적(State Transition)하는 계층이다.

```text
User Snapshot
        │
        ▼
 Rule-based State Engine
        │
        ▼
User State Snapshot
        │
        ▼
State Transition
```

---

# 1. Design Principles

State Engine는 다음 원칙을 따른다.

* State는 **User Snapshot으로부터 계산되는 Label**이다.
* Feature는 저장하지만 State는 계산한다.
* State는 Snapshot Date마다 독립적으로 계산된다.
* Transition은 서로 다른 Snapshot 간의 State 변화로 정의한다.
* 하나의 User는 하나의 Snapshot에서 여러 State를 동시에 가질 수 있다.

예를 들어

```text
User A

2024-01-07

Current State

• Engaged
• Surging
• Deep Diver
• High Value
```

즉 State는 **다차원(Multi-dimensional State)** 으로 표현된다.

---

# 2. State Space

State는 Feature Space의 각 Behavioral Axis를 해석하여 생성된다.

| State Group    | Behavioral Axis                   | 목적       |
| -------------- | --------------------------------- | -------- |
| Funnel         | Intensity, Frequency, Value       | 구매 단계    |
| Momentum       | Velocity, Recency                 | 최근 행동 변화 |
| Browsing Style | Intensity, Diversity, Persistence | 탐색 성향    |
| Customer Value | Value, Frequency, Recency         | 고객 가치    |
| Context        | Context                           | 활동 패턴    |

---

# 3. User State Snapshot

Primary Key

```text
(user_id, snapshot_date)
```

User State Snapshot은 특정 Snapshot Date에서 사용자의 상태(Label)를 저장한다.

---

## 3.1 Schema

| Column         | Description  |
| -------------- | ------------ |
| user_id        | 사용자          |
| snapshot_date  | 기준일          |
| funnel_state   | 성장 퍼널 상태     |
| momentum_state | 행동 변화 상태     |
| browsing_state | 탐색 성향        |
| value_state    | 고객 가치        |
| context_state  | 활동 컨텍스트      |
| state_version  | Rule Version |
| created_at     | 생성 시각        |

---

# 4. Funnel State

사용자가 구매 여정 어디에 위치하는가를 나타낸다.

입력 Feature

* Purchase Frequency
* Cart Frequency
* Revenue
* Buyer Flag
* Account Age

State

| State       | Rule Example                                            |
| ----------- | ------------------------------------------------------- |
| New Visitor | Buyer Flag=0 AND Purchase Frequency=0 AND Account Age≤3 |
| Engaged     | Cart Frequency>0 AND Purchase Frequency=0               |
| Activated   | Purchase Frequency=1                                    |
| Repeated    | Purchase Frequency≥2                                    |
| Expanded    | Revenue≥Threshold AND Purchase Frequency≥Threshold      |

Transition 예시

```text
New
↓

Engaged
↓

Activated
↓

Repeated
↓

Expanded
```

---

# 5. Momentum State

최근 행동 변화.

입력 Feature

* Activity Acceleration
* Purchase Acceleration
* Days Since Last Activity

State

| State    | Rule                                                             |
| -------- | ---------------------------------------------------------------- |
| Surging  | Activity Acceleration > threshold                                |
| Stable   | 변화 없음                                                            |
| Chilling | Activity Acceleration < threshold OR Days Since Last Activity 증가 |

Transition

```text
Stable

↓

Surging

↓

Stable

↓

Chilling
```

---

# 6. Browsing Style

탐색 성향.

입력 Feature

* Product Diversity
* Avg Session Depth
* Product Repeat Rate

State

| State                 | Rule                               |
| --------------------- | ---------------------------------- |
| Deep Diver            | Depth↑ Diversity↓                  |
| Broad Scanner         | Diversity↑ Depth↓                  |
| High Efficiency Buyer | Purchase Frequency↑ Session Depth↓ |
| Window Shopper        | View↑ Purchase=0                   |

---

# 7. Customer Value

고객 가치.

입력 Feature

* Revenue
* Lifetime Revenue
* Purchase Frequency
* AOV
* Buyer Flag

State

| State      | Rule                        |
| ---------- | --------------------------- |
| Champions  | Revenue↑ Frequency↑ Recent↑ |
| High Value | Revenue↑                    |
| Promising  | Buyer Flag=1 AND Tenure≤3   |
| At Risk    | Revenue↑ AND Recency↑       |
| Low Value  | Others                      |

---

# 8. Context State

행동 시간 패턴.

입력 Feature

* Active Hour
* Weekend Ratio

State

| State           | Rule                    |
| --------------- | ----------------------- |
| Early Bird      | Morning Activity Ratio↑ |
| Night Owl       | Night Activity Ratio↑   |
| Weekend Shopper | Weekend Ratio↑          |

---

# 9. User State Snapshot Example

| user | date       | Funnel  | Momentum | Browsing   | Value     | Context   |
| ---- | ---------- | ------- | -------- | ---------- | --------- | --------- |
| U01  | 2024-01-07 | Engaged | Surging  | Deep Diver | Promising | Night Owl |

---

# 10. State Transition

Primary Key

```text
(user_id,
from_date,
to_date)
```

Transition은 두 Snapshot 사이의 State 변화이다.

---

## 10.1 Schema

| Column          | Description           |
| --------------- | --------------------- |
| user_id         | 사용자                   |
| from_date       | 이전 Snapshot           |
| to_date         | 현재 Snapshot           |
| state_group     | Funnel / Momentum ... |
| previous_state  | 이전 State              |
| current_state   | 현재 State              |
| transition      | 상태 변화                 |
| transition_days | 기간                    |

---

## 10.2 Transition Rule

```text
Transition

=

Previous State

+

Current State
```

예)

```text
New

↓

Engaged
```

또는

```text
Stable

↓

Surging
```

---

## 10.3 Transition Example

| User | From      | To        | Group    | Transition          |
| ---- | --------- | --------- | -------- | ------------------- |
| A    | New       | Engaged   | Funnel   | New→Engaged         |
| A    | Stable    | Surging   | Momentum | Stable→Surging      |
| A    | Promising | Champions | Value    | Promising→Champions |

---

# 11. Transition Features

Transition 자체도 분석 Feature가 된다.

| Feature                 | Formula                        |
| ----------------------- | ------------------------------ |
| State Changed           | Previous State ≠ Current State |
| Transition Count        | 누적 State 변경 횟수                 |
| Days In Current State   | 현재 State 지속 일수                 |
| Previous State Duration | 이전 State 유지 기간                 |
| State Entry Count       | 특정 State 진입 횟수                 |
| State Exit Count        | 특정 State 이탈 횟수                 |

---

# 12. Transition Matrix

Transition은 Markov State Matrix 형태로 표현할 수 있다.

예)

| From \ To | New  | Engaged | Activated | Repeated |
| --------- | ---- | ------- | --------- | -------- |
| New       | 0.52 | 0.45    | 0.03      | 0        |
| Engaged   | 0.08 | 0.58    | 0.34      | 0        |
| Activated | 0    | 0.09    | 0.63      | 0.28     |

이를 이용하여

* 전환율(Funnel Conversion)
* Churn Probability
* Expected Next State
* State Survival Time
* CRM Trigger

등을 계산할 수 있다.

---

# 13. State Engine Pipeline

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
──────────────────────
User Feature Snapshot
──────────────────────
      │
      ▼
Rule-based State Engine
      │
      ▼
──────────────────────
User State Snapshot
──────────────────────
      │
      ▼
──────────────────────
State Transition
──────────────────────
      │
      ▼
CRM / Recommendation / Personalization / Analytics
```

# 14. Design Principles

* **User Snapshot**는 State Engine의 유일한 입력(Feature Vector)이다.
* **User State Snapshot**은 특정 시점의 다차원 상태(Label)를 저장한다.
* **State Transition**은 두 Snapshot 간 상태 변화를 저장하며, 상태 변화 이력 자체를 분석 대상으로 활용한다.
* 하나의 사용자는 동일한 Snapshot에서 **Funnel, Momentum, Browsing Style, Customer Value, Context** 등 여러 State Group에 동시에 속할 수 있다.
* Transition은 향후 **Markov Chain, Survival Analysis, Churn Prediction, CRM Trigger Engine**의 입력 데이터로 재사용할 수 있도록 설계한다.
