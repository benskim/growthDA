 **6개의 독립적인 축(Orthogonal Dimensions)** 으로 정리할 수 있습니다. 각 축은 서로 다른 질문에 답하며 함께 조합해서 사용할 수 있습니다.

---

# Matrix 2 User State Framework (최종)

| 차원    | 분류                              | 핵심 질문                | 대표 상태                                                               | 주요 KPI                  |
| ----- | ------------------------------- | -------------------- | ------------------------------------------------------------------- | ----------------------- |
| **1** | **성장 퍼널 (Funnel / Where)**      | 지금 구매 여정 어디에 있는가?    | New Visitor → Engaged → Activated → Repeated → Expanded             | CVR, 구매전환율              |
| **2** | **행동 역학 (Momentum / Dynamics)** | 최근 행동이 살아나는가, 식어가는가? | Surging / Stable / Chilling                                         | Retention, Churn        |
| **3** | **고객 가치 (Customer Value)**      | 얼마나 가치 있는 고객인가?      | VIP / High Value / Promising / Low Value                            | Revenue, AOV, LTV       |
| **4** | **탐색 스타일 (Browsing Style)**     | 어떻게 쇼핑하는가?           | Deep Diver / Broad Scanner / High Efficiency Buyer / Window Shopper | CTR, Session Quality    |
| **5** | **브랜드·상품 선호도 (Preference)**     | 무엇을 선호하는가?           | Brand Loyalist / Brand Nomad / Budget Seeker / Premium Seeker       | Recommendation Accuracy |
| **6** | **사용 컨텍스트 (Context)**           | 언제, 어떤 환경에서 사용하는가?   | Early Bird / Night Owl / Weekend Shopper 등                          | Open Rate, Revisit      |

---

# 1. 성장 퍼널 (Where)

유저가 구매 여정에서 어느 단계에 있는지 정의합니다.

| State       | 의미       |
| ----------- | -------- |
| New Visitor | 신규 유입    |
| Engaged     | 관심 형성    |
| Activated   | 첫 구매     |
| Repeated    | 반복 구매    |
| Expanded    | 고액·대량 구매 |

**목적**

* 전환율 개선
* CRM 자동화
* Funnel 최적화

---

# 2. 행동 역학 (Momentum)

최근 행동 변화량을 봅니다.

| State    | 의미           |
| -------- | ------------ |
| Surging  | 최근 구매 의도 급상승 |
| Stable   | 평소와 비슷       |
| Chilling | 최근 급격히 활동 감소 |

**목적**

* 실시간 타게팅
* Churn 방지
* Trigger Marketing

---

# 3. 고객 가치 (Customer Value)

여기에는 **기존의 객단가(Value-based)** 와 **RFM** 이 사실상 같은 축이므로 통합하는 것이 맞습니다.

최종 상태는 다음 정도면 충분합니다.

| State           | 의미                 |
| --------------- | ------------------ |
| Champions (VIP) | 최근, 자주, 많이 구매      |
| High Value      | 객단가가 매우 높음         |
| Promising       | 신규이지만 성장 가능성 높음    |
| At Risk         | 과거 고가치였으나 최근 활동 감소 |
| Low Value       | 일반 고객              |

평가 기준

* Revenue
* Frequency
* Monetary
* AOV
* LTV

**중복 제거**

기존

* Whale
* High AOV
* Champions
* Can't Lose Them
* Promising

↓

모두 **Customer Value** 하나로 통합 가능

---

# 4. 탐색 스타일 (Browsing Style)

유저가 쇼핑하는 방식을 나타냅니다.

| State                 | 의미          |
| --------------------- | ----------- |
| High Efficiency Buyer | 거의 바로 구매    |
| Window Shopper        | 많이 보지만 안 삼  |
| Deep Diver            | 한 상품 깊게 탐색  |
| Broad Scanner         | 여러 상품 얕게 탐색 |

평가 기준

* Product Diversity
* Session Depth
* View Frequency
* Time to Purchase

---

# 5. 브랜드·상품 선호도 (Preference)

기존의

* Brand Loyalty
* Budget
* Premium

을 하나의 축으로 합칩니다.

| State          | 의미        |
| -------------- | --------- |
| Brand Loyalist | 특정 브랜드 선호 |
| Brand Nomad    | 브랜드 비교형   |
| Budget Seeker  | 저가 중심     |
| Premium Seeker | 고가 중심     |

평가 기준

* Brand Entropy
* Price Preference
* Category Preference

---

# 6. 사용 컨텍스트 (Context)

기존 Time-based를 확장한 개념입니다.

| State           | 의미      |
| --------------- | ------- |
| Early Bird      | 오전 활동   |
| Night Owl       | 심야 활동   |
| Lunch Shopper   | 점심시간 활동 |
| Weekend Shopper | 주말 활동   |

평가 기준

* Active Hour
* Day of Week
* Device
* Channel

---

# 제외한 중복 분류

다음은 별도 축으로 둘 필요가 없습니다.

| 기존 분류            | 이유                 | 최종 포함 위치       |
| ---------------- | ------------------ | -------------- |
| 객단가 가치형          | RFM과 동일한 가치 축      | Customer Value |
| Whale            | VIP의 일부            | Customer Value |
| High AOV         | VIP의 일부            | Customer Value |
| Budget Seeker    | 가격 선호              | Preference     |
| Brand Loyalist   | 브랜드 선호             | Preference     |
| Brand Nomad      | 브랜드 선호             | Preference     |
| Time-based       | Context에 포함        | Context        |
| Search Depth     | Browsing Style에 포함 | Browsing Style |
| Efficiency Buyer | Browsing Style에 포함 | Browsing Style |
| Window Shopper   | Browsing Style에 포함 | Browsing Style |

---

# 최종 Matrix 2 구조

```text
User
│
├── ① Funnel (Where)
│      New → Engaged → Activated → Repeated → Expanded
│
├── ② Momentum (Dynamics)
│      Surging / Stable / Chilling
│
├── ③ Customer Value
│      VIP / High Value / Promising / At Risk / Low Value
│
├── ④ Browsing Style
│      Deep Diver / Broad Scanner
│      High Efficiency / Window Shopper
│
├── ⑤ Preference
│      Brand Loyalist / Brand Nomad
│      Budget / Premium
│
└── ⑥ Context
       Early Bird / Night Owl
       Weekend / Weekday
```

이 구조는 **MECE**에 가깝고, 각 축이 서로 독립적이어서 조합이 가능합니다. 예를 들어 **"Engaged × Surging × High Value × Deep Diver × Brand Loyalist × Night Owl"**처럼 하나의 유저를 다차원적으로 표현할 수 있으며, CRM·추천·푸시 전략에 바로 활용할 수 있는 실무적인 User State Engine의 기반이 됩니다.
