# 실무적 사고 프레임워크

- 분석을 "행동 단계"보다 "질문" 중심으로 구성하는 것입니다.

| 질문                  | 분석 축               | 예시 지표                          |
| ------------------- | ------------------ | ------------------------------ |
| **누가 왔는가?**         | Acquisition        | 채널, 캠페인, 디바이스                  |
| **무엇을 했는가?**        | Engagement         | 세션, 이벤트, 빈도                    |
| **무엇을 탐색했는가?**      | Exploration        | 상품/카테고리 다양성                    |
| **무엇을 선택했는가?**      | Preference         | 브랜드, 카테고리, 가격대                 |
| **얼마나 꾸준한가?**       | Persistence        | 반복률, 브랜드 안정성                   |
| **변화하고 있는가?**       | Momentum           | Activity/Purchase Acceleration |
| **비즈니스 가치를 만들었는가?** | Conversion / Value | 구매, 매출, AOV                    |
| **돌아오는가?**          | Retention          | 재방문, 재구매                       |
| **왜 그런 결과가 나왔는가?**  | Journey / Persona  | 상태 전이, 세그먼트                    |

- State란 사용자가 하고 있는 행동 단계(시간흐름에 따라 변화가능)
| State        | 정의          | 대표 행동                                |
    | ------------ | ----------- | ------------------------------------ |
    | Visitor      | 방문만 함       | session time < 3 seconds                        |
    | Browser     | 관심을 넓게 탐색   | Category, Browse             |
    | Evaluator    | 구매 후보를 검토   | Cart |
    | Activator       | 구매 완료     | Purchase (1회, 2회 상관없음)                       |
    | Dormant      | 일정 기간 활동 없음 | 과거 이벤트 이력있지만 최근 7일간 이력없음 - Inactive Rule  |
    | Churn        | 장기 미활동      | 과거 이벤트 이력있지만 최근 21일간 이력없음 - Churn Rule                           |
- Persona보다 적합한 Behavioral Traits : 사용자가 장기적인 일정기간동안 반복적으로 보이는 행동 성향 [!=Persona]
    | Behavior Trait          | 핵심 질문               | 정의                                | 대표 Metric                                                | Score (0~100) | 해석       |
    | ----------------------- | ------------------- | --------------------------------- | ------------------------------------------------------------ | :-----------: | -------- |
    | **Exploration**         | 얼마나 넓게 탐색하는가?       | '서로 다른 카테고리/브랜드 간의 이동성' 탐색하는 성향        | Search Diversity, Category Diversity, Proudct Diversity          |     0~100     | 탐색 성향    |
    | **Price Sensitivity**   | 가격 변화에 얼마나 민감한가?    | 할인, 쿠폰, 가격 차이에 영향을 받는 성향          | Coupon Usage, Discount Ratio, Sale Purchase Ratio            |     0~100     | 가격 민감도   |
    | **Quality Orientation** | 품질을 얼마나 중시하는가?      | 가격보다 품질, 성능, 프리미엄 가치를 중요하게 여기는 성향 | Premium Brand Ratio, Avg Price Index, Premium Product Ratio      |     0~100     | 품질 지향성   |
    | **Brand Loyalty**       | 특정 브랜드를 얼마나 선호하는가?  | 특정 브랜드를 반복적으로 선택하는 성향             | Big Brand Concentration Index, Repeat Brand Ratio                |     0~100     | 브랜드 충성도  |
    | **Research Tendency**   | 구매 전 얼마나 정보를 수집하는가? | '서로 같은 카테고리/브랜드 내에서의 읻동성'과 단일 상품 단위의 집착도 / 상품을 충분히 확인한 후 구매하는 성향     | compare rate, product view session duration, Product View Depth(Count/freq)               |     0~100     | 정보 탐색 성향 |
    | **Decision Speed**      | 의사결정을 얼마나 빨리 하는가?   | 탐색부터 구매까지 걸리는 시간이 짧거나 긴 성향        | Time to Purchase, Purchase Latency, Sessions Before Purchase |     0~100     | 의사결정 속도  |


## 사고 순서도 (알고리즘)
Goal (무엇을 볼 것인가? — KPI 하락 진단 또는 성장 목표)
   ↓
Opportunity (어디를 볼 것인가?)
   Population(User Class) → State → Behavioral Traits
   ├─ Customer Class : Prospect/ New / Existing / VIP 
   ├─ State : Visit, Browse, Evaluate(Consider), Activate(Buy/ReBuy/Retain), Dorm, Churn
   ├─ Behavioral Traits : Wide-Explore, Price-sensitive, Quality-oriented, Brand-loyal, Deep Research, Fast-decision 
   ↓
Behavior Analysis (무슨 일이 일어나고 있는가?)(사실 Facts 설명)
   * Metric Layer : Activity → Exploration → Preference → Momentum → Conversion (무엇을 볼 것인가?)
   * Segment Layer : Time(weekend, night, morning, lunch, evening)
   └─ Trend * Segment : Metric이 시간에 따라 유의미하게 변하는 Segment가 있나?
   └─ Distribution * Segment : Metric이 전체 평균(Quantiles,Skewness, etc)보다 유의미하게 변하는 Segment가 있나?
   ├─ Relationship
   └─ 회귀분석+Feature Importance : Metric은 KPI를 가장 잘 설명하나? 
   └─ 상관분석 : Metric 무엇과 함께 움직이는가? 
   └─ feature importance 
   ↓
Insight — 가장 가능성 있는 원인은 무엇인가? (가설만들기)
   ├─ 문제 해결이 목표라면 → Root Cause (진단: 왜 나빠졌는가)
   ├─ 성장이 목표라면     → Growth Lever (기회: 무엇을 확대할 것인가)
   └─ Diagnosis 태깅 — 좁혀진 후보에 원인 종류 이름 붙이기 
    * Navigation/Trigger/Interest/Friction
    * Behavior Analysis가 뽑아낸 후보 목록 중에서 "어떤 게 가장 그럴듯한 원인인가"를 좁히기
    1. Root Cause Ranking Logic
        * 시점 일치: 그 Behavior 변화가 시작된 시점이 배포·캠페인·정책 변경 시점과 겹치는가 (제가 앞서 예시에서 "결제 모듈 오류"를 1순위로 둔 이유가 이겁니다 — 앱 업데이트 시점과 정확히 일치)
        * 기여도 크기: Driver Tree로 KPI를 분해했을 때, 이 Behavior 변화가 최종 결과에 실제로 얼마나 기여하는지 (상관은 있어도 기여도가 작으면 후순위)
        * 특이성: 다른 정상 그룹에서는 이 변화가 안 보이는지 (전체에서 다 같이 변했다면 원인이 아니라 계절성 같은 공통 요인일 가능성)
    2. Growth Lever Ranking Logic
        * 확장가능성 : 고가치 기여군(시점/특이점)에 더 많은 고객을 유입할 수 있나?
        예시: "탐색 다양성 높은 Persona가 전환율 2.3배"라는 후보가 있었죠. 이때 확인할 것은 — 이 Persona 조건에 "거의 근접했지만 아슬아슬하게 못 미치는" 유저가 얼마나 많은가입니다. 만약 조건에 근접한 유저가 전체의 20%나 된다면 확장 여지가 크고, 이미 이 조건을 만족하는 유저가 시장의 대부분이라면 확장 여지가 작습니다. 즉 "좋은 패턴"이라고 다 좋은 레버가 아니라, 그 패턴에 도달 가능한 사람이 많이 남아있어야 레버로서 가치가 있습니다.
        * 기대효과크기 : 고가치 기여군의 유입량증가가 KPI 개선으로 연결되나? 
        예시 : 억지로 유저를 8%까지 밀어 넣는다고 똑같이 2.3배가 유지되지 않습니다. 원래 3%는 자연스럽게 그런 성향을 가진 사람들이었고, 새로 편입되는 사람들은 그 성향이 약할 수 있기 때문입니다. 이걸 반영하지 않으면 기대 임팩트를 과대추정하게 됩니다.
        * 미시도영역여부 : 기존 타겟팅 넛지 시도경험이 없는 "블루오션"인가?
        예시 : "야간 사용자 Persona의 활동 재개"라는 후보가 나왔는데, 이미 지난달 "야간 알림 캠페인"이 돌고 있었다면 whitespace 점수가 낮아지고, 반대로 "탐색 다양성 높은 Persona"에는 아직 아무 캠페인도 없었다면 whitespace 점수가 높아 우선순위가 올라갑니다
   ↓
<Scope 재검증>
   ↓   
Expected Effect - 예상 성장/손실 계산 (LTV/Revenue 기준 환산)
   ↓
Experiment (정말 원인인가? — 진단이든 기회든 실행 단계는 동일)
    * 인과검증 : A/B Test, Holdout, DiD, Causal Impact
    * Prioritization(RICE) 
    * Execute/Measure/Learn


## 순서도 (pseudo algorithm)
```
python
def insight_engine(goal, opportunity_seed):
    """
    goal: {"type": "diagnostic" | "growth", "kpi": "revenue" | "retention" | ...}
    opportunity_seed: Alert 또는 Positive Signal에서 넘어온 최초 신호
    """

    # ── 1. Opportunity 좁히기 (Locate) ──────────────────────
    population = narrow_population(opportunity_seed)      # 누구에게?
    state      = narrow_state(population)                 # 어느 여정 단계?
    persona    = narrow_persona(population, state)         # 어떤 유형?
    scope = {"population": population, "state": state, "persona": persona}

    # ── 2. Behavior Analysis: 상관관계 후보 뽑기 ──────────────
    candidates = []
    for metric in all_behavior_metrics(layers=["Activity","Exploration",
                                                "Preference","Momentum","Conversion"]):
        diff = compare_to_baseline(metric, scope=scope, baseline="전체평균 or 과거시점")
        if abs(diff.magnitude) > diff.threshold:
            candidates.append({"metric": metric, "diff": diff})

    # candidates 예: [{"결제 체류시간": +100%}, {"카테고리 다양성": -50%}, ...]
    if len(candidates) == 0:
        return no_signal_found(scope)   # 재현 안 되면 여기서 종료

    # ── 3. Ranking: 후보 중 진짜 원인/레버 좁히기 ──────────────
    for c in candidates:
        if goal.type == "diagnostic":
            c.score = (
                w1 * timing_match(c, event_log=["배포","캠페인","정책변경"]) +   # 시점 일치
                w2 * contribution_to_kpi(c, method="driver_tree") +              # 기여도
                w3 * specificity(c, vs_normal_group=True)                        # 특이성
            )
        else:  # growth
            c.score = (
                w1 * expandability(c) +          # 확장 가능성 (규모를 늘릴 수 있는가)
                w2 * expected_impact(c) +        # 기대 임팩트 크기
                w3 * whitespace(c, vs_current_targeting=True)  # 아직 안 건드린 영역인가
            )

    ranked = sort_desc(candidates, key="score")
    top_candidate = ranked[0]

    # ── 3.5 Scope 재검증 (되돌아가는 경로) ────────────────────
    if top_candidate.contradicts(scope):
        # 예: "Repeat 상태로만 좁혔는데 실제론 Cart 유저도 섞여있었다"
        scope = narrow_opportunity_again(scope, evidence=top_candidate)
        candidates = behavior_analysis(scope)   # 2번부터 재실행
        # (루프 방지를 위해 최대 재시도 횟수 제한)

    # ── 4. Diagnosis Layer 태깅: 원인/레버 유형 이름 붙이기 ────
    if goal.type == "diagnostic":
        tag = classify(top_candidate, taxonomy=["Navigation","Trigger","Interest","Friction"])
        root_cause = {"description": top_candidate.metric, "type": tag}
        impact = estimate_loss(root_cause, unit="LTV/Revenue")
        insight = {"root_cause": root_cause, "expected_loss": impact}
    else:
        tag = classify(top_candidate, taxonomy=["탐색확장형","재방문유도형","전환압축형", ...])
        growth_lever = {"description": top_candidate.metric, "type": tag}
        impact = estimate_gain(growth_lever, unit="LTV/Revenue")
        insight = {"growth_lever": growth_lever, "expected_gain": impact}

    # ── 5. Experiment 추천: 상관관계를 인과관계로 검증 ─────────
    experiment = recommend_experiment(insight, scope)

    return {
        "scope": scope,
        "insight": insight,
        "experiment": experiment
    }

    def contradicts(top_candidate, scope):
    """
    top_candidate의 diff가 scope 내부에서 균질한지 검사.
    균질하지 않으면 = scope 경계 설정이 잘못된 것.
    """
    # scope를 만들 때 썼던 하위 차원별로 다시 쪼개서 diff를 각각 계산
    sub_diffs = []
    for sub_segment in split_by_original_dimensions(scope, dims=["state", "persona"]):
        # 예: scope가 "Repeat 상태"였다면, 그 안을 다시
        #     "진짜 Repeat"와 "Repeat로 분류됐지만 실제 행동은 Cart에 가까운 유저"로 쪼갬
        d = compare_to_baseline(top_candidate.metric, scope=sub_segment)
        sub_diffs.append(d)

    # 균질성 검사: 하위 세그먼트 간 diff 편차가 큰가?
    variance = compute_variance(sub_diffs)
    if variance > homogeneity_threshold:
        return True   # 모순 있음 — scope가 틀렸거나 너무 넓음
    return False

    def narrow_opportunity_again(scope, evidence):
    # 모순을 일으킨 하위 세그먼트를 새로운 scope로 교체
    culprit_segment = find_max_variance_segment(evidence)
    new_state = redefine_state_boundary(scope.state, culprit_segment)
    # 예: "Repeat" → "Repeat(순수)"와 "Repeat(Cart 잔존)"으로 State 경계 자체를 재정의

    return {
        "population": scope.population,   # Population은 유지
        "state": new_state,                # State만 더 세분화
        "persona": recompute_persona(scope.population, new_state)
    }

    if __name__ == "__main__":
        MAX_RETRY = 3
        MIN_SCOPE_SIZE = 100  # 유저 수 기준, 이보다 작아지면 통계적으로 무의미

        retry_count = 0
        while contradicts(top_candidate, scope) and retry_count < MAX_RETRY:
            scope = narrow_opportunity_again(scope, evidence=top_candidate)
            if population_size(scope) < MIN_SCOPE_SIZE:
                break   # 너무 잘게 쪼개졌으면 여기서 멈추고 현재 결과로 진행
            candidates = behavior_analysis(scope)
            top_candidate = rank(candidates)[0]
            retry_count += 1
```

## 질문예시
### 1. 목표가 무엇인가?
* 우리가 성장시키려는 것은 무엇인가?

- 목표(예시)
    - 구매 전환율 증가
    - 재구매율 증가
    - 30일 Retention 개선
    - VIP 고객 확대

### 2. 누가 문제인가?

* 첫 번째 질문 : “전체가 아니라 어떤 집단에서 문제가 발생하는가?”
* 목적 : “전체 평균”이 아니라 문제가 발생한 집단을 특정한다.
* 분할 기준 (예시)
    - 신규 vs 기존
    - 채널별
    - 디바이스별
    - 국가/지역별
    - 가입 코호트별
* 정답(예시)
    - “전환율이 떨어졌다” ❌
    - “최근 4주 내 유입된 Android 신규 유저의 전환율이 떨어졌다” ⭕


### 3. 활동량(유입량)이 줄어서 문제인가?
* 두 번째 질문 : 사용자들이 덜 들어오고 덜 행동하는가?
* 목적 : 문제가 트래픽인지, 행동인지 먼저 구분한다.
    - 시나리오 A: [활동량도 같이 줄어든 경우] ➔ 앱에 매력을 잃음 
    - 시나리오 B: [활동량은 그대로거나 늘었는데, 전환만 안 됨] ➔ 허들 발생 (QA/개발 문제)
    - 시나리오 C: [유입량(Traffic)이 줄어든 경우] if 목표=매출감소 
* 분할 기준
    -  Frequency(count), Momentum, Recency
* 정답(예시)
    - “구매가 줄었다” ❌
    - “구매 이전 단계인 세션 수 자체가 줄었는가?” ⭕

### 4. 활동의 품질(방식)이 문제인가?
* 세 번째 질문 : “활동은 하는데 과거보다 또는 다른 사람(코호트)보다 덜 탐색하는가?”
* 목적 : 활동성의 품질저하 여부를 판단합니다.
* 분할기준
    - Breadth(Diversity), Density(per session/duration), Depth(Repeat)
* 정답(예시)
    1. [Breadth - 다양성] 
        - 오답: “상세 페이지 조회수(PV)가 줄었다.” ❌ (단순 클릭 수 감소인지 취향 방황인지 모름)
        - 정답: “유저당 탐색하는 브랜드나 카테고리의 가짓수(Diversity) 자체가 좁아졌는가?” ⭕
    2. [Duration & Density - 체류 시간과 밀도] 
        - 오답: “Android 유저들의 앱 체류 시간이 늘었으니 긍정적이다.” ❌ (앱이 느려서 갇힌 것일 수 있음)
        - 정답: “체류 시간 대비 유저들의 분당 클릭 수(Density)가 떨어져 멍하니 멈춰 있는가?” ⭕
    3. [Depth - 탐색 깊이]
        - 오답: “최근 신규 유저들의 메인 화면 클릭 수가 줄었다.” ❌ (메인 화면은 단순 유입용 겉핥기임)
        - 정답: “특정 상품을 3회 이상 반복 조회(product_repeat_rate)하는 진심 어린 탐색(Depth)이 줄었는가?” ⭕

### 5. 활동품질 변화의 원인이 무엇인가?
* 네번째 질문 : 활동품질의 변화원인은 시스템적 문제(탐색,가격,결제)인가 비시스템적 문제(동기,선호)인가?
[활동 품질 저하 원인]
  ├── 1. Trigger (유입 동기) : 애초에 "살 맘"이 있는 유저인가?
  ├── 2. Navigation (탐색 효율) : 원하는 상품을 "쉽게" 찾고 있는가?
  ├── 3. Interest (선호 매칭) : 찾은 상품이 유저 취향에 "맞는가"?
  └── 4. Friction (결심 장벽) : 다 맘에 드는데 "왜" 마지막에 망설이는가?
* 목적 : 행동품질과 맥락변화를 찾습니다.
* 분할기준
    * ① Latency & Crash
        * 필수 지표: 평균 페이지 로드 시간 (Page Load Time), Android 앱 버전별 크래시 발생율
        * 해석: 최근 4주 내 업데이트된 Android 특정 버전에서 로딩 속도가 3초 이상 늘어났거나 에러가 터졌는지 검증합니다.
    * ② Micro Funnel-Friction
        * 필수 지표: 상세페이지 조회 대비 장바구니 전환율 (PV-to-Cart Ratio)
        * 해석: 작성하신 마트 변수 중 High-Intent Ponderer(반복 조회) 수치는 높은데, Cart Adder(장바구니 담기)의 전환 비중이 과거 대비 폭락했는지 봅니다. (UI 버그나 옵션 선택창 튕김 증명)
    * ③ Price Elasticity
        * 필수 지표: 상품 가격 구간별(transaction_value_state) 장바구니 및 구매 전환율
        * 해석: 저가 상품의 전환율은 그대로인데, 고가 상품 영역에서만 유저들이 상세 페이지를 보다가 장바구니에 안 담고 Chilling(급랭) 상태로 이탈하는지 비교합니다. (가격 장벽 증명)
    * ④ Persona  Contamination by Channel(Traffic Quality)
        * 필수 지표: 유입 채널(context_state)별 신규 유저의 shopping_persona 분포 비율
        * 해석: 최근 4주 유입된 Android 유저들의 마케팅 채널을 쪼갰을 때, 목적형 고객(High-Intent Ponderer)의 유입은 줄어들고 단순 구경꾼(Standard Shopper)이나 체리피커 유입 비중이 늘어났는지 확인합니다. (마케팅 타겟팅 실패 증명)
    * ⑤ Preference/Diversity Shift
        * 필수 지표: 주차별 brand_stability(브랜드 집중도) 및 category_diversity(카테고리 다양성)
        * 해석: 유저들이 원래 파던 브랜드에서 벗어나 여러 카테고리를 의미 없이 방황(Brand Explorer 노드로 대거 이동)하고 있는지 봅니다. (유저 선호의 대이동 또는 추천 피드 매칭 실패 증명)
    * ⑥ LifeStyle Temporal Bias
        * 필수 지표: 주차별 temporal_context_state(주말/평일 비율) 및 time_activity_state(시간대)
        * 해석: 최근 4주 신규 유저들이 주로 주말 쇼핑족(Weekend Warrior)이나 야간 올빼미족(Night Owl) 위주로 채워지면서, 평일 직장인 대비 느긋하고 얕은 탐색 품질을 보이고 있는지 검증합니다.
* 분할기준(예시)
    - 브랜드 점유율 변화
    - 카테고리 점유율 변화
    - 가격대 이동
    - 채널 이동
* 정답(예시)
    1. Trigger (유입 동기 레이어)
        * 오답: “Android 신규 유저 수가 줄었다.” ❌
        * 정답: “목적을 가진 고의도 탐색꾼(High-Intent Ponderer)의 유입 비율이 줄고, 체리피커나 단순 구경꾼의 비율이 늘었는가?” ⭕
        * 정답: “평일 직장인(Weekday Regular)의 유입이 줄고, 주말 쇼핑족(Weekend Warrior) 위주로 유입 지형이 바뀌었는가?” ⭕

    2. Navigation (탐색 효율 레이어)
        * 오답: “Android 앱 클릭 수가 감소했다.” ❌
        * 정답: “체류 시간은 그대로인데 분당 클릭 수(Density)가 급감하여 유저들이 화면 로딩을 기다리며 멈춰 있는가?” ⭕
        * 정답: “원하는 것을 찾지 못해 여러 브랜드와 카테고리를 의미 없이 방황하는 과다 탐색(Brand Explorer) 유저가 늘었는가?” ⭕

    3. Interest (선호 매칭 레이어)
        * 오답: “특정 브랜드 제품의 매출이 떨어졌다.” ❌
        * 정답: “유저들이 한 브랜드에 정착하지 못하고 이 브랜드 저 브랜드를 철새처럼 떠도는 브랜드 유동성(brand_stability 저하)이 심해졌는가?” ⭕
        * 정답: “프리미엄 카테고리 선호 유저층이 가성비를 추구하는 중저가 카테고리 퍼소나로 이동했는가?” ⭕

    4. Friction (결심 장벽 레이어)
        * 오답: “장바구니 담기 횟수가 감소했다.” ❌
        * 정답: “상품 상세 페이지를 3회 이상 반복 조회(product_repeat_rate)할 만큼 살 마음은 가득한데, 마지막 장바구니(Cart Adder) 관문에서 가로막히는가?” ⭕
        * 정답: “장바구니에는 착착 담는데, 결제 단계에서 예상치 못한 비용(배송비 등)이나 결제 오류를 만나 활성도가 급랭(Chilling)하는가?” ⭕

### 6. 이 원인은 재무적으로 얼마나 심각(중요)한 요소인가?
* 다섯번째 질문 : “이 발견(원인/성장 요인)을 방치하거나 극대화했을 때, 회사의 최종 손익계산서(P&L)와 현금 흐름에는 몇 개월 동안 정확히 얼마의 돈(Money)이 움직이는가?”
* 목적 :  리소스(개발 인력, 마케팅 예산)를 이 문제 해결에 최우선으로 투입해야 하는 수치적 정당성과 우선순위(Priority)를 확보합니다.
* 분할 기준 : 재무적 심각성(손실 또는 기회 가치) --> [직접성]+[시간 축] 기준 2x2 매트릭스를 구성합니다.
                    [ 단기적 임팩트 ]                    [ 장기적 임팩트 ]
    [ 직접적 가치 ]   A. 즉각적 매출/비용 변화            B. 고객생애가치(LTV) 및 리텐션 변화
    [ 간접적 가치 ]   C. 마케팅/운영 예산 매몰 비용       D. 브랜드 자산 및 바이럴 전파력 손실
    * A. Immediate Revenue Loss: Momentum(acceleration), Frequency, Purchase interval vairance --> revenue, aov
    * B. Lifetime Value Erosion: (Churn) + 향후 1년간 발생하지 않게 될 미래 매출의 총합 (LTV 매몰).
    * C. Sunk Marketing Cost: 이 유저들을 데려오기 위해 최근 4주간 집행했으나, 전환 실패로 인해 허공으로 날아간 마케팅 광고비 (CAC 낭비).
    * D. Brand Referral Damage: 실망한 유저가 playstore에 악평을 남기거나 주변에 부정 바이럴을 퍼뜨려, 미래의 잠재 고객 유입이 막히는 비용.
* 정오답 예시
    * 오답: “Android 신규 유저 2,000명의 전환율이 떨어졌으니 매출 타격이 큽니다.” ❌
    * (이유: ‘타격이 크다’는 주관적이며, 구체적으로 어떤 돈이 얼만큼 날아가는지 중복과 누락이 가득함)
    * 정답: “이번 Android 장바구니 오류의 재무적 손실은 총 1억 1,000만 원입니다. 이는 당장 이번 주 증발한 결제액 3,000만 원(직접·단기)과, 해당 유저들의 향후 6개월 기대 LTV 매몰 비용 7,000만 원(직접·장기), 그리고 이들을 모객하기 위해 낭비된 마케팅 비용 1,000만 원(간접·단기)의 합입니다.” ⭕

### 7. 문제해결을 위해 어떠한 실험가설을 세우나?
* 마지막 질문 : “원인제거 + 성장요인 복제위해, 어떤 세그먼트에게, 어떤 트리거(Trigger)를 제공하면, 유저 심리가 어떻게 변화하여, 최종 비즈니스 지표가 개선될 것인가?”
[실험 단계 핵심 분석]
  ├── 1. 대상자 발굴 (Target Segment): "어떤 세그먼트"에게 줄 것인가?
  ├── 2. 트리거 최적화 (Trigger Matching): "어떤 트리거"가 먹힐 것인가?
  ├── 3. 메커니즘 검증 (Behavioral Proxy): "유저 심리 변화"를 어떻게 측정할 것인가?
  ├── 4. 결과 분석 (A/B Test Outcome): "최종 지표가 개선" 되었는가?
  └── 5. 부작용 검증 (Cannibalization Check): 이 과정에서 "잃은 것"은 없는가?
* 목적 : 
    * 감에 의존한 일회성 땜질식 액션이 아니라, 인과관계가 명확히 통제된 과학적 실험 체계(A/B Test)를 설계하기 위함입니다.
    * 액션 실패 시에도 리스크를 최소화하고, 성공 시에는 이 비즈니스 성공 방정식을 전사적으로 확장하기 위함입니다.
* 분할 기준 :
    1. 대상자 발굴 분석 (Target Segment Analysis)
    목적: 실험의 효과가 가장 극대화될 수 있는 정확한 타겟 유저 집단을 정의합니다.
    수행해야 할 분석:
    1) 데이터 충분할 때: [세그먼트 임계값(Threshold) 최적화 분석]
    분할기준 : 이탈 임계점 분석 (Recency x Churn Risk Baseline), 행동 깊이별 잔존 전환율 분석 (Friction Line), 가속도 반전 마진 분석 (Acceleration Elasticity)
    예시: lifetime_account_age_days <= 30인 신규 유저 중, rolling_event_count >= 20이지만 rolling_cart_count = 0인 ‘장바구니 미도달 고활성 유저’의 볼륨과 이탈률을 분석하여 실험 대상(Sample Size)을 확정합니다.
    2) 데이터가 없거나 신규 비즈니스일 때: [유입 소스 코호트 분석]
    과거 이력이 없으므로 유입 마케팅 채널(UTM 컴페인)이나 유저가 최초 가입 시 선택한 선호 카테고리(온보딩 서베이) 데이터 기반으로 확정.

    2. 트리거 최적화 분석 (Trigger Matching Analysis)
    목적: 대상 유저에게 UI를 바꿔줄지(시스템), 쿠폰을 줄지(비시스템) 가장 확률이 높은 자극제를 매칭합니다.
    수행해야 할 분석: 
    1) who : [과거 유저 행동 매칭 분석 (Propensity Score)]
    예시: 이탈 위험(At-Risk)에 처한 유저들의 과거 time_activity_state를 봅니다. 야간 올빼미족(Night Owl) 비율이 70%라면, 낮에 쏘는 일괄 푸시는 효과가 없습니다. “야간 11시 타겟 앱 푸시 발송”이라는 구체적인 트리거의 스펙(시점, 채널)을 유저 데이터 기반으로 도출해 냅니다.
    2) how much : 개입이 '비시스템적'일 때 [할인 민감도 분석]
    예시 : (CRM 쿠폰 등)  구매력과 결제 스타일 파악 <-- transaction_value_state와 가격 탄력성을 매핑 
    3) where : 개입이 '시스템적(UI/UX/알고리즘 업데이트)'일 때 [Duration 및 주요 이동 경로(Path) 분석]
    예시 : 체류 화면과 클릭 동선 파악 --> 어떤 화면에 새로운 UI 컴포넌트를 심어야 할지 결정.

    3. 유저 심리(행동) 변화 분석 (Behavioral Proxy Analysis)
    목적: 유저의 눈에 보이지 않는 심리(만족, 귀찮음, 확신)가 인앱 행동 흔적으로 어떻게 나타나는지 대리 지표로 정의합니다.
    수행해야 할 분석: [선행 행동 지표(Leading Indicator) 정의 분석]
    최종 결제(매출)가 일어나기 전, 유저가 ‘트리거를 받고 마음이 움직였다’는 것을 증명할 '징검다리 지표'찾기.
    1) 단기 구매 유도가 목적일 때:  [단기 마이크로 전환율 분석(인앱 전환 속도)], [평균 상품 조회 수(PV)의 상승폭]
    예시 : 트리거 노출 즉시 장바구니에 담거나 스크롤을 내리는지 확인
    2) 유저의 '선호 이동/취향 변화'가 목적일 때:  [카테고리 탐색 밀도(Density) 변동 분석],[brand_diversity 확장 분석]?
    예시 : 쿠폰 하나 썼다고 심리가 바뀌지 않으므로, 실험 개시 후 유저가 탐색하는 브랜드 수가 넓어지는지 확인

    4. 최종 지표 결과 분석 (A/B Test Outcome Analysis)
    목적: 실험군(A)과 대조군(B)을 비교하여 최종 비즈니스 지표가 통계적으로 유의미하게 개선되었는지 판단합니다.
    수행해야 할 분석:
    1) 모든 환경이 통제된 완벽한 A/B 테스트가 가능할 때: [Frequentist 통계 검정 및 LTV 코호트 분석] 
    - 예시: 트리거를 제공한 그룹(A)과 제공하지 않은 그룹(B)의 최종 customer_value_state(Champions 비율)와 transaction_value_state(결제액)를 비교합니다.  실험군과 대조군을 5:5로 쪼개어 단순 p-value(유의성 검정)와 전환율 차이를 비교. 실험 이후 4주간의 누적 매출 상승 곡선추적
    2) 대조군을 설정할 수 없을 때 (전체 배포 등): [성향점수 매칭(PSM)], [통제망 시계열 분석(Causal Impact)]
    - 인위적으로 과거 유사 시점의 유저나 다른 기기 유저를 가상 대조군으로 생성해 '전후 효과 검증'.

    5. 부작용 및 간섭 분석 (Cannibalization & Guardrail Analysis)
    목적: 하나의 지표를 올리려다 다른 핵심 지표를 망가뜨리지 않았는지(Guardrail) 검증합니다.
    수행해야 할 분석: [가드레일 메트릭(Guardrail Metric) 교차 분석]
    예시: 장바구니 미도달 유저에게 3,000원 쿠폰(비시스템 트리거)을 줘서 전환율을 올렸다고 칩니다. 이때 “쿠폰 발급 비용 때문에 마진율(Profit Margin)이 박살 나지 않았는가?” 혹은 “원래 제값 주고 살 유저에게 쿠폰을 퍼주어 자연 매출을 갉아먹지 않았는가?”를 MECE하게 검증하여 처방의 최종 손익을 계산합니다.
    1) 쿠폰/할인 실험일 때: [수익성(Profitability) 분석] 
    - 예산제약상 인당 마진율 하락 폭과 재무적 ROI를 계산
    2) 추천 알고리즘 변경 실험일 때: [부정적 피드백(Negative Signal) 및 단기 리텐션 분석]
    - 돈의 문제보다는 유저가 피로감을 느껴 앱을 지울 수 있으므로, 푸시 차단율이나 일주일 내 앱 삭제율

* 정오답 예시
    * 오답: “Android 신규 유저들에게 앱을 잘 고쳐주고 쿠폰도 주면 전환율이 다시 올라갈 것이다.” ❌
    * (이유: 앱 수정과 쿠폰 지급이라는 두 가지 변수가 뒤섞여(누락/중복), 나중에 지표가 올라도 버그 패치 때문인지 쿠폰 때문인지 인과관계를 증명할 수 없음)
    * 정답: “Android v1.3 유저 중 장바구니 미도달 집단(High-Intent Ponderer)을 대상으로, 
    [가설 1: 하단 장바구니 버튼의 UI 가림 현상을 패치(기능 개입)하면 전환율이 5%p 회복될 것이다]와 
    [가설 2: 버그를 겪은 유저에게 장바구니 전용 3천 원 쿠폰 푸시를 발송(인센티브 개입)하면 활성도(Chilling)가 Surging으로 반전될 것이다]라는 두 실험을 독립적으로 분리하여 검증한다.” ⭕

## analytics system layer
| Priority | Layer                   | 목적                       | 대표 시각화                                                     |
| -------- | ----------------------- | ------------------------ | ---------------------------------------------------------- |
| **P0**   | Goal                    | 어떤 KPI를 개선할 것인가          | KPI 카드, 트렌드                                                |
| **P1**   | Population              | 어느 세그먼트에서 문제가 발생했는가      | Heatmap, Pivot, Small Multiples                            |
| **P2**   | Behavioral Diagnosis    | 어떤 행동 특성이 변했는가           | Behavior Radar, Feature Distribution, Parallel Coordinates |
| **P3**   | Journey & Outcome       | 행동이 어떤 결과로 이어졌는가         | Funnel, Sankey, Cohort, Retention Curve                    |
| **P4**   | Root Cause              | 시스템/선호/가격/유입 등 무엇이 원인인가  | Driver Tree, Decision Tree, Correlation Matrix             |
| **P5**   | Impact & Prioritization | 어떤 문제가 가장 큰 비즈니스 영향을 주는가 | Impact vs Effort Matrix, Revenue Waterfall, Bubble Chart   |
| **P6**   | Experiment & Learning   | 어떤 가설을 검증하고 무엇을 학습했는가    | Experiment Board, A/B Test Dashboard, Guardrail Monitoring |
