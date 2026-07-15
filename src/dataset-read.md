데이터 파이프라인으로 보는 차이 예시

Raw Event: 유저가 구매 버튼을 누름
{"click_id": "99A", "html_element": "btn-pay-submit", "x_pos": 240, "y_pos": 450, "ip": "1.2.4"}
    
Canonical Event: 로그를 표준 규격으로 정제
{"user_id": "user77", "event_type": "click", "target": "submit_button", "timestamp": 1778834640}
    
Behavior Event (View / Cart / Purchase): 비즈니스 의미 부여
{"user_id": "user77", "action": "Purchase", "amount": 55000, "item": "Socks"}