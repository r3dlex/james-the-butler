<template>
  <div id="app">
    <header class="app-header">
      <img src="/logo.svg" alt="James the Butler" width="36" height="36" />
      <h1>James the Butler</h1>
    </header>

    <main class="chat-container">
      <div class="messages" ref="messagesRef">
        <div v-if="messages.length === 0" class="welcome">
          <img src="/logo.svg" alt="" width="64" height="64" class="welcome-logo" />
          <p>How can I help you today?</p>
        </div>
        <div
          v-for="(msg, i) in messages"
          :key="i"
          :class="['message', msg.role]"
        >
          <div class="message-role">{{ msg.role === 'user' ? 'You' : 'James' }}</div>
          <div class="message-content">{{ msg.displayText }}</div>
        </div>
        <div v-if="loading" class="message assistant">
          <div class="message-role">James</div>
          <div class="message-content typing">
            <span></span><span></span><span></span>
          </div>
        </div>
      </div>

      <form class="input-bar" @submit.prevent="sendMessage">
        <input
          v-model="input"
          type="text"
          placeholder="Send a message..."
          :disabled="loading"
          autofocus
        />
        <button type="submit" :disabled="loading || !input.trim()">Send</button>
      </form>
    </main>
  </div>
</template>

<script setup lang="ts">
import { ref, nextTick } from 'vue'

interface ChatMessage {
  role: 'user' | 'assistant'
  content: string
  displayText: string
}

const messages = ref<ChatMessage[]>([])
const input = ref('')
const loading = ref(false)
const messagesRef = ref<HTMLElement | null>(null)

const API_URL = 'http://localhost:4000/api/chat'

function scrollToBottom() {
  nextTick(() => {
    if (messagesRef.value) {
      messagesRef.value.scrollTop = messagesRef.value.scrollHeight
    }
  })
}

async function sendMessage() {
  const text = input.value.trim()
  if (!text || loading.value) return

  messages.value.push({ role: 'user', content: text, displayText: text })
  input.value = ''
  loading.value = true
  scrollToBottom()

  const apiMessages = messages.value.map((m) => ({
    role: m.role,
    content: m.content,
  }))

  try {
    const res = await fetch(API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ messages: apiMessages }),
    })

    const data = await res.json()

    if (!res.ok) {
      messages.value.push({
        role: 'assistant',
        content: data.error || 'Something went wrong',
        displayText: data.error || 'Something went wrong',
      })
    } else {
      const textBlock = data.content?.find((b: any) => b.type === 'text')
      const reply = textBlock?.text || JSON.stringify(data)
      messages.value.push({
        role: 'assistant',
        content: reply,
        displayText: reply,
      })
    }
  } catch (err: any) {
    messages.value.push({
      role: 'assistant',
      content: 'Failed to reach the server.',
      displayText: 'Failed to reach the server.',
    })
  } finally {
    loading.value = false
    scrollToBottom()
  }
}
</script>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  background: #0d0d1a;
  color: #e0e0e0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

#app {
  display: flex;
  flex-direction: column;
  height: 100vh;
}

.app-header {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 20px;
  border-bottom: 1px solid #1a1a2e;
  background: #0d0d1a;
}

.app-header h1 {
  font-family: Georgia, 'Times New Roman', serif;
  font-size: 18px;
  color: #d4a574;
  font-weight: normal;
}

.chat-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  max-width: 800px;
  width: 100%;
  margin: 0 auto;
  padding: 0 16px;
}

.messages {
  flex: 1;
  overflow-y: auto;
  padding: 24px 0;
}

.welcome {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  gap: 16px;
  opacity: 0.5;
}

.welcome-logo {
  opacity: 0.6;
}

.welcome p {
  font-size: 18px;
  color: #888;
}

.message {
  margin-bottom: 20px;
}

.message-role {
  font-size: 12px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 4px;
  color: #888;
}

.message.user .message-role {
  color: #d4a574;
}

.message.assistant .message-role {
  color: #7a9ec2;
}

.message-content {
  font-size: 15px;
  line-height: 1.6;
  white-space: pre-wrap;
  word-wrap: break-word;
}

.message.user .message-content {
  color: #e0e0e0;
}

.message.assistant .message-content {
  color: #c8c8d0;
}

.typing {
  display: flex;
  gap: 4px;
  padding: 8px 0;
}

.typing span {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #d4a574;
  opacity: 0.3;
  animation: pulse 1.4s ease-in-out infinite;
}

.typing span:nth-child(2) { animation-delay: 0.2s; }
.typing span:nth-child(3) { animation-delay: 0.4s; }

@keyframes pulse {
  0%, 80%, 100% { opacity: 0.3; transform: scale(0.8); }
  40% { opacity: 1; transform: scale(1); }
}

.input-bar {
  display: flex;
  gap: 8px;
  padding: 16px 0 24px;
  border-top: 1px solid #1a1a2e;
}

.input-bar input {
  flex: 1;
  padding: 12px 16px;
  border: 1px solid #2a2a3e;
  border-radius: 8px;
  background: #12121f;
  color: #e0e0e0;
  font-size: 15px;
  outline: none;
  transition: border-color 0.2s;
}

.input-bar input:focus {
  border-color: #d4a574;
}

.input-bar input::placeholder {
  color: #555;
}

.input-bar button {
  padding: 12px 24px;
  border: none;
  border-radius: 8px;
  background: #d4a574;
  color: #0d0d1a;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: opacity 0.2s;
}

.input-bar button:hover:not(:disabled) {
  opacity: 0.9;
}

.input-bar button:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}
</style>
