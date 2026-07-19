/**
 * RagChat — Glassmorphic Chat Widget
 * Embed on any website with a single <script> tag.
 *
 * Usage:
 *   <script src="YOUR_DOMAIN/widget/static/widget.js"
 *           data-tenant-slug="your-client-slug"></script>
 */
(function () {
  "use strict";

  // --- Config ---
  const scriptTag = document.currentScript;
  const SLUG = scriptTag?.getAttribute("data-tenant-slug") || "default";
  const API_BASE = scriptTag?.src.replace(/\/widget\/static\/widget\.js$/, "") || "";

  let config = {
    org_name: "Chat Assistant",
    theme: {
      primary_color: "#6366f1",
      background_color: "rgba(255, 255, 255, 0.7)",
      text_color: "#1e293b",
      border_color: "rgba(99, 102, 241, 0.3)",
      blur_amount: "20px",
      font_family: "'Inter', 'Segoe UI', sans-serif",
      border_radius: "16px",
      header_gradient: "linear-gradient(135deg, #6366f1, #8b5cf6)",
      bot_bubble_bg: "rgba(99, 102, 241, 0.1)",
      user_bubble_bg: "rgba(99, 102, 241, 0.85)",
      position: "bottom-right",
    },
  };

  let chatHistory = [];
  let isOpen = false;

  // --- Fetch widget config ---
  async function loadConfig() {
    try {
      const res = await fetch(`${API_BASE}/api/widget/${SLUG}/config`);
      if (res.ok) {
        const data = await res.json();
        config = { ...config, ...data };
      }
    } catch (e) {
      console.warn("RagChat: Could not load config, using defaults");
    }
    applyTheme();
  }

  function applyTheme() {
    const t = config.theme;
    const root = document.getElementById("ragchat-widget");
    if (!root) return;
    root.style.setProperty("--rc-primary", t.primary_color);
    root.style.setProperty("--rc-bg", t.background_color);
    root.style.setProperty("--rc-text", t.text_color);
    root.style.setProperty("--rc-border", t.border_color);
    root.style.setProperty("--rc-blur", t.blur_amount);
    root.style.setProperty("--rc-font", t.font_family);
    root.style.setProperty("--rc-radius", t.border_radius);
    root.style.setProperty("--rc-header-gradient", t.header_gradient);
    root.style.setProperty("--rc-bot-bg", t.bot_bubble_bg);
    root.style.setProperty("--rc-user-bg", t.user_bubble_bg);
  }

  // --- Build DOM ---
  function createWidget() {
    if (document.getElementById("ragchat-widget")) return;

    const root = document.createElement("div");
    root.id = "ragchat-widget";
    root.innerHTML = `
      <style>${getStyles()}</style>

      <!-- Floating Button -->
      <div id="rc-toggle" onclick="window.RagChat.toggle()">
        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
        </svg>
      </div>

      <!-- Chat Window -->
      <div id="rc-window" class="rc-hidden">
        <!-- Header -->
        <div id="rc-header">
          <div id="rc-header-info">
            <div id="rc-avatar">🤖</div>
            <div>
              <div id="rc-org-name"></div>
              <div id="rc-status">Online</div>
            </div>
          </div>
          <button id="rc-close" onclick="window.RagChat.toggle()">✕</button>
        </div>

        <!-- Messages -->
        <div id="rc-messages">
          <div id="rc-welcome"></div>
        </div>

        <!-- Input -->
        <div id="rc-input-area">
          <div id="rc-input-wrap">
            <textarea id="rc-input" placeholder="Ask me anything..." rows="1"
                      onkeydown="window.RagChat.handleKey(event)"></textarea>
            <button id="rc-send" onclick="window.RagChat.send()">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="22" y1="2" x2="11" y2="13"/>
                <polygon points="22 2 15 22 11 13 2 9 22 2"/>
              </svg>
            </button>
          </div>
          <div id="rc-powered">Powered by RagChat</div>
        </div>
      </div>
    `;

    document.body.appendChild(root);
    applyTheme();

    document.getElementById("rc-org-name").textContent = config.org_name;
    document.getElementById("rc-welcome").innerHTML = `
      <div class="rc-msg rc-bot">
        <div class="rc-bubble">Hello! I'm the ${config.org_name} assistant. How can I help you today?</div>
      </div>
    `;
  }

  function getStyles() {
    return `
      #ragchat-widget {
        position: fixed;
        z-index: 999999;
        font-family: var(--rc-font);
        all: initial;
      }
      #ragchat-widget * {
        box-sizing: border-box;
        margin: 0;
        padding: 0;
      }

      /* Floating Toggle Button */
      #rc-toggle {
        position: fixed;
        bottom: 24px;
        right: 24px;
        width: 60px;
        height: 60px;
        border-radius: 50%;
        background: var(--rc-header-gradient);
        color: #fff;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
        box-shadow: 0 8px 32px rgba(99, 102, 241, 0.4);
        transition: all 0.3s ease;
        z-index: 999999;
      }
      #rc-toggle:hover {
        transform: scale(1.1);
        box-shadow: 0 12px 40px rgba(99, 102, 241, 0.5);
      }
      #rc-toggle:active { transform: scale(0.95); }

      /* Chat Window */
      #rc-window {
        position: fixed;
        bottom: 96px;
        right: 24px;
        width: 400px;
        max-width: calc(100vw - 48px);
        height: 600px;
        max-height: calc(100vh - 140px);
        border-radius: var(--rc-radius);
        background: var(--rc-bg);
        backdrop-filter: blur(var(--rc-blur));
        -webkit-backdrop-filter: blur(var(--rc-blur));
        border: 1px solid var(--rc-border);
        box-shadow: 0 24px 80px rgba(0, 0, 0, 0.25), 0 0 1px rgba(0, 0, 0, 0.1);
        display: flex;
        flex-direction: column;
        overflow: hidden;
        transition: all 0.35s cubic-bezier(0.4, 0, 0.2, 1);
        z-index: 999998;
      }
      #rc-window.rc-hidden {
        opacity: 0;
        pointer-events: none;
        transform: translateY(20px) scale(0.95);
      }

      /* Header */
      #rc-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 16px 18px;
        background: var(--rc-header-gradient);
        color: #fff;
        flex-shrink: 0;
      }
      #rc-header-info {
        display: flex;
        align-items: center;
        gap: 12px;
      }
      #rc-avatar {
        width: 40px;
        height: 40px;
        border-radius: 50%;
        background: rgba(255,255,255,0.2);
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 20px;
      }
      #rc-org-name {
        font-size: 15px;
        font-weight: 600;
        color: #fff;
      }
      #rc-status {
        font-size: 12px;
        color: rgba(255,255,255,0.8);
      }
      #rc-close {
        background: rgba(255,255,255,0.2);
        border: none;
        color: #fff;
        width: 32px;
        height: 32px;
        border-radius: 50%;
        cursor: pointer;
        font-size: 14px;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: background 0.2s;
      }
      #rc-close:hover { background: rgba(255,255,255,0.3); }

      /* Messages */
      #rc-messages {
        flex: 1;
        overflow-y: auto;
        padding: 16px;
        display: flex;
        flex-direction: column;
        gap: 12px;
        scroll-behavior: smooth;
      }
      #rc-messages::-webkit-scrollbar { width: 4px; }
      #rc-messages::-webkit-scrollbar-thumb { background: rgba(0,0,0,0.15); border-radius: 2px; }

      .rc-msg { display: flex; max-width: 85%; }
      .rc-bot { align-self: flex-start; }
      .rc-user { align-self: flex-end; }

      .rc-bubble {
        padding: 10px 14px;
        border-radius: 14px;
        font-size: 14px;
        line-height: 1.5;
        color: var(--rc-text);
        word-break: break-word;
      }
      .rc-bot .rc-bubble {
        background: var(--rc-bot-bg);
        border-bottom-left-radius: 4px;
      }
      .rc-user .rc-bubble {
        background: var(--rc-user-bg);
        color: #fff;
        border-bottom-right-radius: 4px;
      }

      /* Typing indicator */
      .rc-typing .rc-bubble::after {
        content: "";
        display: inline-block;
        width: 4px;
        height: 4px;
        border-radius: 50%;
        background: currentColor;
        margin-left: 2px;
        animation: rc-blink 1.4s infinite both;
      }
      .rc-typing .rc-bubble::before {
        content: "";
        display: inline-block;
        width: 4px;
        height: 4px;
        border-radius: 50%;
        background: currentColor;
        margin-right: 2px;
        animation: rc-blink 1.4s infinite 0.2s both;
      }
      @keyframes rc-blink {
        0%, 80%, 100% { opacity: 0.2; }
        40% { opacity: 1; }
      }

      /* Input area */
      #rc-input-area {
        padding: 12px 16px 8px;
        border-top: 1px solid var(--rc-border);
        background: var(--rc-bg);
        flex-shrink: 0;
      }
      #rc-input-wrap {
        display: flex;
        align-items: flex-end;
        gap: 8px;
        padding: 8px 12px;
        border-radius: 12px;
        background: rgba(255,255,255,0.6);
        border: 1px solid var(--rc-border);
        transition: border-color 0.2s;
      }
      #rc-input-wrap:focus-within { border-color: var(--rc-primary); }

      #rc-input {
        flex: 1;
        border: none;
        outline: none;
        background: transparent;
        font-family: var(--rc-font);
        font-size: 14px;
        color: var(--rc-text);
        resize: none;
        max-height: 100px;
        line-height: 1.4;
      }
      #rc-input::placeholder { color: rgba(0,0,0,0.35); }

      #rc-send {
        width: 36px;
        height: 36px;
        border-radius: 50%;
        background: var(--rc-primary);
        color: #fff;
        border: none;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        flex-shrink: 0;
        transition: all 0.2s;
      }
      #rc-send:hover { opacity: 0.85; transform: scale(1.05); }
      #rc-send:disabled { opacity: 0.5; cursor: not-allowed; }

      #rc-powered {
        text-align: center;
        font-size: 10px;
        color: rgba(0,0,0,0.25);
        margin-top: 6px;
        padding-bottom: 2px;
      }

      /* Mobile */
      @media (max-width: 480px) {
        #rc-window {
          bottom: 0;
          right: 0;
          width: 100%;
          max-width: 100%;
          height: 100%;
          max-height: 100%;
          border-radius: 0;
        }
      }
    `;
  }

  // --- Chat Logic ---
  function addMessage(text, role) {
    const messagesEl = document.getElementById("rc-messages");
    const div = document.createElement("div");
    div.className = `rc-msg rc-${role}`;
    div.innerHTML = `<div class="rc-bubble">${escapeHtml(text)}</div>`;
    messagesEl.appendChild(div);
    messagesEl.scrollTop = messagesEl.scrollHeight;
    return div;
  }

  function addTyping() {
    const messagesEl = document.getElementById("rc-messages");
    const div = document.createElement("div");
    div.className = "rc-msg rc-bot rc-typing";
    div.id = "rc-typing";
    div.innerHTML = `<div class="rc-bubble">thinking</div>`;
    messagesEl.appendChild(div);
    messagesEl.scrollTop = messagesEl.scrollHeight;
    return div;
  }

  function removeTyping() {
    const el = document.getElementById("rc-typing");
    if (el) el.remove();
  }

  function escapeHtml(text) {
    const d = document.createElement("div");
    d.textContent = text;
    return d.innerHTML;
  }

  async function sendMessage() {
    const input = document.getElementById("rc-input");
    const query = input.value.trim();
    if (!query) return;

    input.value = "";
    input.style.height = "auto";
    addMessage(query, "user");
    chatHistory.push({ role: "user", content: query });

    const typing = addTyping();
    document.getElementById("rc-send").disabled = true;

    try {
      const res = await fetch(`${API_BASE}/api/chat/${SLUG}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          query,
          chat_history: chatHistory.slice(-10),
        }),
      });

      removeTyping();

      if (!res.ok) {
        addMessage("Sorry, something went wrong. Please try again.", "bot");
        return;
      }

      const data = await res.json();
      addMessage(data.answer, "bot");
      chatHistory.push({ role: "assistant", content: data.answer });
    } catch (e) {
      removeTyping();
      addMessage("Network error. Please check your connection.", "bot");
    } finally {
      document.getElementById("rc-send").disabled = false;
    }
  }

  function handleKey(e) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
    // Auto-resize textarea
    const ta = e.target;
    ta.style.height = "auto";
    ta.style.height = Math.min(ta.scrollHeight, 100) + "px";
  }

  function toggle() {
    isOpen = !isOpen;
    const win = document.getElementById("rc-window");
    if (isOpen) {
      win.classList.remove("rc-hidden");
      setTimeout(() => document.getElementById("rc-input")?.focus(), 100);
    } else {
      win.classList.add("rc-hidden");
    }
  }

  // --- Init ---
  window.RagChat = { toggle, send: sendMessage, handleKey };
  createWidget();
  loadConfig();
})();
