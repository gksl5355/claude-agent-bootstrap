---
name: configure-notifications
description: Configure notifications (Telegram, Discord, Slack) for spawn-team session events — team completion, input needed, errors.
triggers:
  - "configure notifications"
  - "setup notifications"
  - "알림 설정"
  - "telegram"
  - "discord webhook"
  - "slack webhook"
---

# Configure Notifications

spawn-team 세션 이벤트 발생 시 알림을 받는다.

**알림 이벤트:**
- 팀 전체 작업 완료 (shutdown_request 전 시점)
- circuit breaker 발동 (사용자 판단 필요)
- 에이전트 스폰 실패 (롤백 발생)
- 쿼터 임계치 도달
- AskUserQuestion 대기 중 (입력 필요)

**지원 플랫폼:** Telegram / Discord (Webhook) / Slack (Webhook)

---

## 플랫폼 선택

AskUserQuestion:
**"어떤 알림 서비스를 사용할까요?"**
1. **Telegram** — 모바일/데스크탑. Bot token + chat ID
2. **Discord** — Webhook URL. 서버 채널 연동
3. **Slack** — Incoming Webhook URL

---

## Telegram 설정

### Bot 토큰 발급
1. Telegram에서 @BotFather 검색
2. `/newbot` 전송 → 이름/username 설정
3. Token 수신 (형식: `123456789:ABCdef...`)

### Chat ID 확인
1. 봇에게 `/start` 전송
2. `https://api.telegram.org/bot{TOKEN}/getUpdates` 방문
3. `"chat":{"id":YOUR_CHAT_ID}` 값 복사

### 설정 저장
```bash
CONFIG=~/.claude/.spawn-notifications.json
cat > "$CONFIG" << EOF
{
  "enabled": true,
  "platform": "telegram",
  "telegram": {
    "botToken": "{BOT_TOKEN}",
    "chatId": "{CHAT_ID}"
  },
  "events": ["team-complete", "circuit-breaker", "spawn-failed", "quota-threshold", "input-needed"]
}
EOF
```

### 테스트
```bash
TOKEN="{BOT_TOKEN}"
CHAT_ID="{CHAT_ID}"
curl -s "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "text=spawn-team 알림 설정 완료 ✓"
```

---

## Discord 설정

### Webhook 생성
1. Discord 서버 설정 → 연동 → 웹후크 → 새 웹후크
2. 채널 선택 → Webhook URL 복사

### 설정 저장
```bash
CONFIG=~/.claude/.spawn-notifications.json
cat > "$CONFIG" << EOF
{
  "enabled": true,
  "platform": "discord",
  "discord": {
    "webhookUrl": "{WEBHOOK_URL}"
  },
  "events": ["team-complete", "circuit-breaker", "spawn-failed", "quota-threshold", "input-needed"]
}
EOF
```

### 테스트
```bash
curl -s -H "Content-Type: application/json" \
  -d '{"content": "spawn-team 알림 설정 완료 ✓"}' \
  "{WEBHOOK_URL}"
```

---

## Slack 설정

### Webhook 생성
1. https://api.slack.com/apps → Create New App
2. Incoming Webhooks → 활성화 → Add New Webhook
3. 채널 선택 → URL 복사 (`https://hooks.slack.com/services/...`)

### 설정 저장
```bash
CONFIG=~/.claude/.spawn-notifications.json
cat > "$CONFIG" << EOF
{
  "enabled": true,
  "platform": "slack",
  "slack": {
    "webhookUrl": "{WEBHOOK_URL}"
  },
  "events": ["team-complete", "circuit-breaker", "spawn-failed", "quota-threshold", "input-needed"]
}
EOF
```

### 테스트
```bash
curl -s -H "Content-Type: application/json" \
  -d '{"text": "spawn-team 알림 설정 완료 ✓"}' \
  "{WEBHOOK_URL}"
```

---

## spawn-team에서 알림 전송

알림을 보낼 시점에 Leader가 직접 실행:

```bash
send_notification() {
  local msg="$1"
  local CONFIG=~/.claude/.spawn-notifications.json

  [ -f "$CONFIG" ] || return
  local enabled=$(jq -r '.enabled' "$CONFIG")
  [ "$enabled" = "true" ] || return

  local platform=$(jq -r '.platform' "$CONFIG")

  case "$platform" in
    telegram)
      local token=$(jq -r '.telegram.botToken' "$CONFIG")
      local chat=$(jq -r '.telegram.chatId' "$CONFIG")
      curl -s "https://api.telegram.org/bot${token}/sendMessage" \
        -d "chat_id=${chat}" -d "text=${msg}" > /dev/null
      ;;
    discord)
      local url=$(jq -r '.discord.webhookUrl' "$CONFIG")
      curl -s -H "Content-Type: application/json" \
        -d "{\"content\": \"${msg}\"}" "$url" > /dev/null
      ;;
    slack)
      local url=$(jq -r '.slack.webhookUrl' "$CONFIG")
      curl -s -H "Content-Type: application/json" \
        -d "{\"text\": \"${msg}\"}" "$url" > /dev/null
      ;;
  esac
}

# 사용 예:
# send_notification "팀 작업 완료: test-ecommerce — 28/28 PASS"
# send_notification "⚠️ circuit breaker 발동: products-be 3회 실패, 판단 필요"
```

---

## 참고

omc의 configure-notifications 전체 문서 (더 많은 플랫폼/이벤트/훅 템플릿):
- https://github.com/Yeachan-Heo/oh-my-claudecode/tree/main/skills/configure-notifications
