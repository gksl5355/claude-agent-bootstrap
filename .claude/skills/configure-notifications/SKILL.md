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

Receive alerts when spawn-team session events occur.

**Alert events:**
- Team-wide task completion (before shutdown_request)
- Circuit breaker fired (user judgment needed)
- Agent spawn failure (rollback occurred)
- Quota threshold reached
- AskUserQuestion pending (input needed)

**Supported platforms:** Telegram / Discord (Webhook) / Slack (Webhook)

---

## Platform Selection

AskUserQuestion:
**"Which notification service would you like to use?"**
1. **Telegram** — Mobile/desktop. Requires Bot token + chat ID
2. **Discord** — Webhook URL. Server channel integration
3. **Slack** — Incoming Webhook URL

---

## Telegram Setup

### Get Bot Token
1. Search for @BotFather in Telegram
2. Send `/newbot` → set name/username
3. Receive token (format: `123456789:ABCdef...`)

### Get Chat ID
1. Send `/start` to your bot
2. Visit `https://api.telegram.org/bot{TOKEN}/getUpdates`
3. Copy `"chat":{"id":YOUR_CHAT_ID}` value

### Save Configuration
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

### Test
```bash
TOKEN="{BOT_TOKEN}"
CHAT_ID="{CHAT_ID}"
curl -s "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT_ID}" \
  --data-urlencode "text=spawn-team notification setup complete ✓"
```

---

## Discord Setup

### Create Webhook
1. Discord server settings → Integrations → Webhooks → New Webhook
2. Select channel → Copy Webhook URL

### Save Configuration
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

### Test
```bash
curl -s -H "Content-Type: application/json" \
  -d '{"content": "spawn-team notification setup complete ✓"}' \
  "{WEBHOOK_URL}"
```

---

## Slack Setup

### Create Webhook
1. https://api.slack.com/apps → Create New App
2. Incoming Webhooks → Enable → Add New Webhook
3. Select channel → Copy URL (`https://hooks.slack.com/services/...`)

### Save Configuration
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

### Test
```bash
curl -s -H "Content-Type: application/json" \
  -d '{"text": "spawn-team notification setup complete ✓"}' \
  "{WEBHOOK_URL}"
```

---

## Sending Notifications from spawn-team

Leader executes directly at notification points:

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
        --data-urlencode "chat_id=${chat}" --data-urlencode "text=${msg}" > /dev/null
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

# Examples:
# send_notification "Team complete: test-ecommerce — 28/28 PASS"
# send_notification "⚠️ Circuit breaker fired: products-be 3 failures, judgment needed"
```

---

## Reference

omc's configure-notifications full docs (more platforms/events/hook templates):
- https://github.com/Yeachan-Heo/oh-my-claudecode/tree/main/skills/configure-notifications
