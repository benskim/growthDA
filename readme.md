# StateFlow Analytics Lab

**State-based Product Analytics Platform**
Version 0.1 (MVP)

---

## 1. Vision

### Background

현재 대부분의 Product Analytics는 Event 중심으로 설계되어 있다.

예를 들어 Mixpanel, Amplitude와 같은 도구에서는 Page View, Click, Purchase와 같은 Event를 수집하고 이를 기반으로 Funnel, Retention, Cohort, Dashboard를 구축한다.

이 방식은 제품의 현재 상태를 모니터링하는 데에는 적합하지만, 사용자의 행동을 하나의 연속적인 상태 변화(Process)로 이해하기에는 한계가 있다.

실무에서도 다음과 같은 문제가 자주 발생한다.

- Funnel은 Funnel 분석 도구에서 수행된다.
- Retention은 Cohort Report에서 확인한다.
- Survival Analysis는 별도의 Notebook에서 분석한다.
- Machine Learning 모델은 Feature Table을 새롭게 만든다.
- A/B Test는 Experiment Platform에서 운영된다.

즉, 모든 분석이 동일한 사용자 행동을 다루고 있음에도 서로 다른 데이터 모델과 분석 단위를 사용한다.

### Vision

본 프로젝트는 Product Analytics의 분석 단위를 Event가 아닌 **State Transition**으로 재정의한다.

사용자는 Event를 직접 분석하는 대신, Event를 통해 정의된 State의 변화 과정을 분석한다.

예를 들어,

```
New → Explorer → Interested → Activated → Repeat Buyer → Habit → Advocate
```

와 같은 상태 모델을 정의하면,

- Funnel은 **State Transition Rate**가 되고,
- Retention은 **State Persistence**가 되며,
- Survival Analysis는 **State Duration Analysis**가 되고,
- Machine Learning은 **Transition Prediction**이 되며,
- Causal Inference는 **Transition Driver Validation**으로 귀결된다.

즉, 모든 분석 기법이 하나의 State Machine 위에서 연결된다.

```
User Journey
        │
        ▼
Raw Event Log
        │
        ▼
Rolling Feature Engineering
        │
        ▼
State Timeline
        │
        ▼
Transition Matrix
        │
        ▼
Transition Probability
        │
        ▼
Next-State Prediction
```

---

## 2. Product Goal

본 프로젝트는 Dashboard를 만드는 것이 아니다.

목표는 다음과 같다.

> Event Data로부터 Product Analytics 전체 과정을 학습할 수 있는 Interactive Analytics Platform을 구축한다.

사용자는 데이터셋 하나만으로 다음 과정을 모두 경험할 수 있어야 한다.

1. 행동 정의
2. 이벤트 정의
3. Metric 정의
4. State 정의
5. Journey 분석
6. Driver 분석
7. Causal 분석
8. Experiment 설계

---

## 3. Design Principles

**Principle 1 — Event is not the business object.**
Event는 관측 데이터일 뿐이다. 실제 분석의 대상은 사용자 상태(State)이다.

**Principle 2 — Metric is a Semantic Layer.**
Metric은 단순한 집계값이 아니다. Metric은 State를 정의하기 위한 Feature Layer이다.
예: `recency`, `frequency`, `monetary`는 모두 State Assignment를 위한 Feature의 상위개념이다.

**Principle 3 — Everything becomes Transition.**
모든 분석 결과는 하나의 질문으로 귀결된다: 현재 어떤 사용자가 어떤 상태에서 어떤 상태로 이동하는가?

**Principle 4 — Analytics should lead to Action.**
분석은 Dashboard에서 끝나지 않는다. 최종 결과는 어떤 사용자에게, 언제, 어떤 실험을 수행할 것인지를 제안해야 한다.

---

## 4. Scope

### Included (전체 비전 기준)

- Ecommerce Dataset
- Event Modeling
- Behavior Modeling
- Metric Layer
- Rule-based State Engine
- Journey Analysis
- Driver Analysis
- Causal Validation
- Experiment Recommendation

### Excluded (전체 비전 기준)

- Real-time Streaming
- Kafka
- Spark
- Multi-tenant Architecture
- User Authentication
- Online Feature Store
- Distributed Processing

> 실제 실행 범위(v0.1)는 `docs/v0.1-scope.md`를 참고. v0.1은 이 전체 비전 중 Phase 1~5만 얇게 구현한 축소 버전이다.

---

## 5. User Persona

- **Primary User**: Product Analyst
- **Secondary User**: Data Analyst
- **Learning User**: Data Science Student

본 플랫폼은 "서비스 운영 도구"가 아니라 "분석 학습 플랫폼"이다.

---

## 6. Domain Model

```
User → Behavior → Event → Metric → State → Journey → Transition → Insight → Experiment
```

각 객체는 이전 계층을 추상화한 결과이다.

---

## 7. System Architecture

시스템은 3개의 Layer로 구성된다.

### Data Layer

원시 Event를 저장한다.

```
Raw Event → Canonical Event → Metric Table → State Table
```

- metrix, state는 별도의 파일로 정의한다.


### Analytics Layer

분석 알고리즘을 수행한다: Journey, Funnel, Retention, Survival, Driver, Causal

모든 알고리즘은 State Table을 입력으로 사용한다.

### Presentation Layer

사용자가 Interactive하게 분석을 수행한다: Dashboard, Graph, Sankey, Timeline, Report

---

## 8. Roadmap (Phase별 할 일)

각 Phase는 이전 Phase 위에 얹는 구조다. Phase 1이 끝나야 Phase 2가 의미를 갖는다.

### Phase 1 — Data Foundation
- [ ] Ecommerce 공개 데이터셋 선정 (예: Olist, Kaggle Ecommerce Events)
- [ ] Raw Event → Canonical Event 스키마 정의 (event_name, user_id, timestamp, properties)
- [ ] 로컬 DB 세팅 (DuckDB)
- [ ] 데이터 적재 스크립트 (CSV/Parquet → DuckDB)
- [ ] 기본 데이터 품질 체크 (null, 중복, 시간 역전 이벤트)

### Phase 2 — Behavior & Event Modeling
- [ ] 원시 이벤트를 Behavior 단위로 그룹핑 (view, cart, purchase 등)
- [ ] Event Taxonomy 표 작성 (event_name ↔ behavior 매핑)
- [ ] 이벤트 정제 규칙 문서화 (bot 필터링, 세션 정의 등)

### Phase 3 — Metric Layer
- [ ] 사용자 단위 집계 user behaviour Metric 설계 (recency, frequency, monetary 등)
- [ ] Metric 계산 SQL/함수 작성
- [ ] Metric Table 생성 (batch, 일 1회 갱신 가정)

### Phase 4 — State Engine
- [ ] State 목록 정의 (New → Explorer → Interested → Cart → Activated → Repeat Buyer → Habit → Advocate)
- [ ] 초기엔 Rule-based (if-else / SQL CASE)로 구현
- [ ] State 배정 함수 → State Table 생성
- [ ] (향후) Rule을 외부화해서 사용자가 직접 수정할 수 있는 DSL/YAML 설계

### Phase 5 — Journey Analytics
- [ ] State Table 기반 Funnel(State Transition Rate) 계산
- [ ] Retention(State Persistence) 계산
- [ ] Sankey/Timeline 시각화

### Phase 6 — Driver Analytics
- [ ] State 전이에 영향 주는 Feature 상관관계 분석
- [ ] 간단한 분류 모델(logistic regression 등)로 다음 State 예측

### Phase 7 — Causal Analytics
- [ ] Driver 후보를 인과적으로 검증 (propensity matching, diff-in-diff 등)
- [ ] 통계적 난이도가 급상승하는 구간 — 별도 리서치 타임 필요

### Phase 8 — Experimentation
- [ ] Driver/Causal 결과 기반 실험 대상군 추천 로직
- [ ] 실험 설계 템플릿 (A/B 그룹, 성공 지표, 기간)
- [ ] 실험 결과 해석 대시보드

---

## 9. MVP Modules (전체 비전 기준)

1. Dataset Explorer
2. Behavior Modeling
3. Event Taxonomy
4. Metric Layer
5. State Modeling
6. Journey Modeling
7. Driver Analysis
8. Causal Validation
9. Experiment Recommendation

---

## 10. Success Criteria

- 하나의 Ecommerce Dataset만으로 전체 분석 Workflow를 수행할 수 있다.
- 사용자가 새로운 State를 정의하면 모든 분석 결과가 자동으로 갱신된다.
- 모든 분석은 동일한 State Model을 기반으로 수행된다.
- 분석 결과가 실험 가능한 Action으로 연결된다.

---

## 11. 문서 구조 (전체 비전 기준, 확장 시)

프로젝트 규모가 커질 경우 다음과 같이 문서를 분리한다. (v0.1 단계에서는 prd.md + v0.1-scope.md만 유지)

```
docs/
│
├── prd.md                 # 제품 비전과 범위 (본 문서)
├── v0.1-scope.md           # v0.1 축소 실행 범위
├── architecture.md         # 시스템 아키텍처 (확장 시 작성)
├── domain-model.md         # Behavior/Event/Metric/State 도메인 모델 (확장 시 작성)
├── data-model.md           # ERD 및 테이블 스키마 (확장 시 작성)
├── state-engine.md         # State 정의와 Rule Engine (확장 시 작성)
├── metric-layer.md         # Metric DSL 및 Feature 생성 (확장 시 작성)
├── analytics-engine.md     # Journey, Driver, Causal 분석 구조 (확장 시 작성)
├── experimentation.md      # 실험 프레임워크 (확장 시 작성)
├── roadmap.md              # 개발 일정과 마일스톤 (확장 시 작성)
└── adr/
    ├── 0001-duckdb.md
    ├── 0002-rule-based-state.md
    ├── 0003-semantic-metric-layer.md
    └── ...
```

domain-model.md와 state-engine.md는 이 프로젝트의 핵심 차별화 요소이므로, 확장 단계에 진입하면 가장 먼저 상세하게 작성하는 것을 추천한다.
