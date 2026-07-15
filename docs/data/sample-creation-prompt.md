# Objective

Generate a synthetic ecommerce user journey dataset for validating a User State Engine and User State Transition Engine.

The generated dataset must simulate realistic user behavior over time so that both user states and state transitions can be reconstructed solely from the event log through feature engineering.

The generation process must follow the causal order:

User Persona
→ Initial State
→ Behavioral Evolution
→ Event Log
→ Feature Engineering
→ State Reconstruction
→ State Transition

---

# Observation Period

30 consecutive days

(The period should be long enough to observe multiple user state transitions.)

---

# Dataset Size

Generate approximately

- 30 users
- 1,500–3,000 events

Each user should exhibit a unique behavioral journey.

---

# Data Granularity

Event-level log.

Each row represents one user interaction.

---

# Raw Schema

Each event must contain the following fields.

- event_time
- user_id
- user_session
- event_type (view, cart, purchase)
- product_id
- category_code
- brand
- price
- device
- channel

---

# Feature Space

The event log must support calculation of the following features.

## Intensity

- Event Frequency
- View Frequency
- Cart Frequency
- Session Frequency

## Diversity

- Product Diversity
- Brand Diversity
- Category Diversity
- Category Entropy

## Velocity

- Activity Acceleration
- Purchase Velocity
- Time to First Purchase

## Persistence

- Product Repeat Rate
- Brand Stability
- Interest Persistence

## Value

- Revenue
- Purchase Frequency
- Average Order Value (AOV)

## Recency

- Last Activity Days
- Last Purchase Days

## Preference

- Preferred Brand
- Preferred Category
- Average Viewed Price

## Context

- Active Hour
- Weekend Ratio
- Mobile Device Ratio

---

# State Space

The generated feature table must allow reconstruction of the following user states.

① Funnel

- New Visitor
- Engaged
- Activated
- Repeated
- Expanded

② Momentum

- Surging
- Stable
- Chilling

③ Customer Value

- Low Value
- Promising
- High Value
- VIP
- At Risk

④ Browsing Style

- Window Shopper
- High Efficiency Buyer
- Broad Scanner
- Deep Diver

⑤ Preference

- Brand Loyalist
- Brand Nomad
- Budget Seeker
- Premium Seeker

⑥ Context

- Early Bird
- Night Owl
- Weekday Shopper
- Weekend Shopper

---

# User Journey Design

Before generating events, first design the intended journey of every user.

Each user must experience at least one meaningful state transition.

Examples

User01

New Visitor
→ Engaged
→ Activated
→ Repeated

User02

New Visitor
→ Window Shopper
→ Chilling

User03

Engaged
→ Surging
→ Activated
→ VIP

User04

Brand Nomad
→ Brand Loyalist

User05

Budget Seeker
→ Premium Seeker

User06

Deep Diver
→ High Efficiency Buyer

The transitions should emerge naturally from changing user behavior instead of manually assigning labels.

---

# Behavioral Constraints

The generated behavior should satisfy the following.

• Window Shopper

Many product views, no purchases.

• Deep Diver

Repeatedly views only a few products.

• Broad Scanner

Views many products across many categories.

• Brand Loyalist

More than 80% of interactions belong to one brand.

• Brand Nomad

Frequently switches brands.

• Budget Seeker

Mostly interacts with low-priced products.

• Premium Seeker

Mostly interacts with expensive products.

• Surging

Activity sharply increases during the final week.

• Chilling

Activity sharply decreases during the final week.

• Early Bird

More than 70% of events occur between 06:00–09:00.

• Night Owl

More than 70% of events occur between 23:00–02:00.

• VIP

Multiple high-value purchases.

---

# Feature Engineering

The generated event log should allow feature computation using rolling windows.

Recommended rolling window

- 7-day
or
- 14-day

so that user states evolve naturally over time.

---

# Output

Produce the following outputs separately.

## 1. Raw Event Log

CSV format.

---

## 2. Feature Table

One row per user per rolling window.

Example

window_end_date
user_id
event_frequency
product_diversity
activity_acceleration
brand_stability
revenue
...

---

## 3. State Timeline

One row per user per rolling window.

Example

date,user_id,funnel,momentum,value,browsing,preference,context

2025-01-07,U01,New Visitor,Stable,Low Value,Window Shopper,Brand Nomad,Night Owl

2025-01-14,U01,Engaged,Surging,Promising,Deep Diver,Brand Loyalist,Night Owl

2025-01-21,U01,Activated,Stable,High Value,Deep Diver,Brand Loyalist,Night Owl

2025-01-28,U01,Repeated,Stable,VIP,High Efficiency Buyer,Brand Loyalist,Night Owl

---

## 4. Transition Matrix

Summarize all observed state transitions.

Example

New Visitor → Engaged

Engaged → Activated

Activated → Repeated

Repeated → Expanded

Window Shopper → High Efficiency Buyer

Brand Nomad → Brand Loyalist

Budget Seeker → Premium Seeker

---

## 5. Design Explanation

Briefly explain why each user's behavior resulted in each transition.