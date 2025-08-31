// Dooms AI Chat - External Script
(function() {
  let isInitializing = true;
  let isLoading = false;

  // DOM elements (queried after DOMContentLoaded)
  let statusDot, statusText, setupProgress, progressBar, progressText,
      chatMessages, messageInput, sendButton, githubLink;

  // History management variables
  let currentConversation = [];
  let historyData = [];
  let isHistoryVisible = false;
  let historyButton, historyPanel, historyOverlay, historyList, historySearchInput,
      saveCurrentBtn, clearHistoryBtn, historyCloseBtn;

  function cacheDom() {
    statusDot = document.getElementById('statusDot');
    statusText = document.getElementById('statusText');
    setupProgress = document.getElementById('setupProgress');
    progressBar = document.getElementById('progressBar');
    progressText = document.getElementById('progressText');
    chatMessages = document.getElementById('chatMessages');
    messageInput = document.getElementById('messageInput');
    sendButton = document.getElementById('sendButton');
    githubLink = document.getElementById('githubLink');
  }

  function ensureDom() {
    if (!statusDot || !statusText || !setupProgress || !progressBar || !progressText || !chatMessages || !messageInput || !sendButton) {
      cacheDom();
    }
  }

  // Basic HTML escaping to safely display hidden thinking content
  function escapeHtml(str) {
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
  }

  // Minimal, safe Markdown renderer: supports headings, lists, blockquotes,
  // bold, italics, inline code, code fences, links, hr. Escapes HTML by default.
  function renderMarkdown(md) {
    if (!md) return '';
    const lines = String(md).split('\n');
    let html = '';
    let inCode = false;
    let codeBuffer = [];
    let inList = false;
    let listBuffer = [];
    let inQuote = false;
    let quoteBuffer = [];

    function flushCode() {
      if (inCode) {
        html += '<pre><code>' + escapeHtml(codeBuffer.join('\n')) + '</code></pre>';
        inCode = false; codeBuffer = [];
      }
    }
    function flushList() {
      if (inList) {
        html += '<ul>' + listBuffer.map(it => '<li>' + it + '</li>').join('') + '</ul>';
        inList = false; listBuffer = [];
      }
    }
    function flushQuote() {
      if (inQuote) {
        html += '<blockquote>' + quoteBuffer.join('<br>') + '</blockquote>';
        inQuote = false; quoteBuffer = [];
      }
    }
    function applyInline(s) {
      let out = escapeHtml(s);
      // Unescape common markdown escape sequences for emphasis/code so they render
      out = out.replace(/\\([*_`])/g, '$1');
      // Bold: **text** and __text__
      out = out.replace(/\*\*(.+?)\*\*/g, '<strong>$1<\/strong>');
      out = out.replace(/__(.+?)__/g, '<strong>$1<\/strong>');
      // Italic: *text* and _text_
      out = out.replace(/(^|[^*])\*(?!\*)([^*\n]+)\*(?!\*)/g, '$1<em>$2<\/em>');
      out = out.replace(/(^|[^_])_(?!_)([^_\n]+)_(?!_)/g, '$1<em>$2<\/em>');
      // Inline code
      out = out.replace(/`([^`]+?)`/g, '<code>$1<\/code>');
      // Links
      out = out.replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g, '<a href="$2" target="_blank" rel="noopener noreferrer">$1<\/a>');
      return out;
    }

    for (let i = 0; i < lines.length; i++) {
      const raw = lines[i];
      if (/^```/.test(raw)) {
        if (inCode) { flushCode(); } else { flushList(); flushQuote(); inCode = true; }
        continue;
      }
      if (inCode) { codeBuffer.push(raw); continue; }

      if (/^\s*([-*_]){3,}\s*$/.test(raw)) { flushList(); flushQuote(); html += '<hr>'; continue; }

      const h = raw.match(/^(#{1,6})\s+(.*)$/);
      if (h) { flushList(); flushQuote(); const level = h[1].length; html += '<h' + level + '>' + applyInline(h[2]) + '</h' + level + '>'; continue; }

      const bq = raw.match(/^\s*>\s?(.*)$/);
      if (bq) { flushList(); if (!inQuote) { inQuote = true; quoteBuffer = []; } quoteBuffer.push(applyInline(bq[1])); continue; } else { flushQuote(); }

      const li = raw.match(/^\s*[-*]\s+(.*)$/);
      if (li) { flushQuote(); if (!inList) { inList = true; listBuffer = []; } listBuffer.push(applyInline(li[1])); continue; } else { flushList(); }

      if (/^\s*$/.test(raw)) { continue; }

      html += '<p>' + applyInline(raw) + '</p>';
    }

    flushCode(); flushList(); flushQuote();
    return html;
  }

  function updateSendButton() {
    ensureDom();
    if (!messageInput || !sendButton) return;
    const hasText = messageInput.value.trim().length > 0;
    sendButton.disabled = isInitializing || isLoading || !hasText;
  }

  function sendMessage() {
    ensureDom();
    if (!messageInput) return;
    const message = messageInput.value.trim();
    if (!message || isInitializing || isLoading) {
      console.log('Cannot send:', { message: !!message, isInitializing, isLoading });
      return;
    }
    console.log('Sending message:', message);

    // Clear input
    messageInput.value = '';
    messageInput.style.height = 'auto';

    // Set loading state
    isLoading = true;
    updateSendButton();

    // Send to QML backend via console log bridge
    console.log('SEND_MESSAGE:' + message);
  }

  function autoResizeTextarea(ev) {
    const el = ev.target;
    el.style.height = 'auto';
    el.style.height = Math.min(el.scrollHeight, 120) + 'px';
    updateSendButton();
  }

  function onKeydown(ev) {
    if (ev.key === 'Enter' && !ev.shiftKey) {
      ev.preventDefault();
      sendMessage();
    }
  }

  function initListeners() {
    ensureDom();
    if (messageInput) {
      messageInput.addEventListener('input', autoResizeTextarea);
      messageInput.addEventListener('keydown', onKeydown);
    }
    if (sendButton) {
      sendButton.addEventListener('click', sendMessage);
    }
    if (githubLink) {
      githubLink.addEventListener('click', function(e) {
        e.preventDefault();
        try { window.open(githubLink.href, '_blank'); } catch (e) {}
      });
    }
  }

  // History Management Functions
  function initHistoryElements() {
    historyButton = document.getElementById('historyButton');
    historyPanel = document.getElementById('historyPanel');
    historyOverlay = document.getElementById('historyOverlay');
    historyList = document.getElementById('historyList');
    historySearchInput = document.getElementById('historySearchInput');
    saveCurrentBtn = document.getElementById('saveCurrentBtn');
    clearHistoryBtn = document.getElementById('clearHistoryBtn');
    historyCloseBtn = document.getElementById('historyCloseBtn');
  }

  function initHistoryListeners() {
    if (historyButton) {
      historyButton.addEventListener('click', toggleHistory);
    }
    if (historyCloseBtn) {
      historyCloseBtn.addEventListener('click', closeHistory);
    }
    if (historyOverlay) {
      historyOverlay.addEventListener('click', closeHistory);
    }
    if (saveCurrentBtn) {
      saveCurrentBtn.addEventListener('click', saveCurrentConversation);
    }
    if (clearHistoryBtn) {
      clearHistoryBtn.addEventListener('click', clearAllHistory);
    }
    if (historySearchInput) {
      historySearchInput.addEventListener('input', filterHistory);
    }
  }

  function toggleHistory() {
    isHistoryVisible = !isHistoryVisible;
    if (isHistoryVisible) {
      loadHistoryData();
      renderHistoryList();
      historyPanel.classList.add('visible');
      historyOverlay.classList.add('visible');
    } else {
      closeHistory();
    }
  }

  function closeHistory() {
    isHistoryVisible = false;
    historyPanel.classList.remove('visible');
    historyOverlay.classList.remove('visible');
  }

  function saveCurrentConversation() {
    if (currentConversation.length === 0) {
      console.log('No conversation to save');
      return;
    }

    const now = new Date();
    const timestamp = now.toISOString();
    const dateStr = now.toLocaleDateString() + ' ' + now.toLocaleTimeString();
    
    // Generate title from first user message
    const firstUserMessage = currentConversation.find(msg => msg.role === 'user');
    const title = firstUserMessage ? 
      firstUserMessage.content.substring(0, 50) + (firstUserMessage.content.length > 50 ? '...' : '') :
      'Untitled Conversation';

    const conversationData = {
      id: 'conv_' + Date.now(),
      title: title,
      timestamp: timestamp,
      dateStr: dateStr,
      messages: [...currentConversation],
      messageCount: currentConversation.length
    };

    // Send to QML backend to save
    console.log('SAVE_HISTORY:' + JSON.stringify(conversationData));
    
    // Add to local history data
    historyData.unshift(conversationData);
    renderHistoryList();
    
    console.log('Conversation saved:', title);
  }

  function clearAllHistory() {
    if (confirm('Are you sure you want to clear all chat history? This cannot be undone.')) {
      historyData = [];
      console.log('CLEAR_HISTORY:');
      renderHistoryList();
      console.log('All history cleared');
    }
  }

  function loadHistoryData() {
    // Request history from QML backend
    console.log('LOAD_HISTORY:');
  }

  function loadConversation(conversationId) {
    const conversation = historyData.find(conv => conv.id === conversationId);
    if (!conversation) return;

    // Clear current chat
    if (chatMessages) {
      chatMessages.innerHTML = '';
    }
    
    // Load conversation messages
    currentConversation = [...conversation.messages];
    
    // Render messages
    conversation.messages.forEach(msg => {
      window.addMessage(msg.role, msg.content, msg.thinking || '');
    });

    closeHistory();
    console.log('Conversation loaded:', conversation.title);
  }

  function deleteConversation(conversationId) {
    if (confirm('Are you sure you want to delete this conversation?')) {
      historyData = historyData.filter(conv => conv.id !== conversationId);
      console.log('DELETE_HISTORY:' + conversationId);
      renderHistoryList();
    }
  }

  function filterHistory() {
    const searchTerm = historySearchInput.value.toLowerCase();
    renderHistoryList(searchTerm);
  }

  function renderHistoryList(searchTerm = '') {
    if (!historyList) return;

    const filteredHistory = searchTerm ? 
      historyData.filter(conv => 
        conv.title.toLowerCase().includes(searchTerm) ||
        conv.messages.some(msg => msg.content.toLowerCase().includes(searchTerm))
      ) : historyData;

    if (filteredHistory.length === 0) {
      historyList.innerHTML = `
        <div class="history-empty">
          <div class="history-empty-icon">📝</div>
          <div class="history-empty-text">${searchTerm ? 'No matching conversations' : 'No chat history yet'}</div>
          <div class="history-empty-subtitle">${searchTerm ? 'Try a different search term' : 'Start a conversation to save it here'}</div>
        </div>`;
      return;
    }

    historyList.innerHTML = filteredHistory.map(conv => `
      <div class="history-item" onclick="loadConversation('${conv.id}')">
        <div class="history-item-header">
          <div class="history-item-title">${conv.title}</div>
          <div class="history-item-date">${conv.dateStr}</div>
        </div>
        <div class="history-item-preview">${getConversationPreview(conv)}</div>
        <div class="history-item-actions">
          <button class="history-item-action" onclick="event.stopPropagation(); deleteConversation('${conv.id}')" title="Delete">
            <svg viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
              <path d="M5.5 5.5A.5.5 0 0 1 6 6v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm2.5 0a.5.5 0 0 1 .5.5v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm3 .5a.5.5 0 0 0-1 0v6a.5.5 0 0 0 1 0V6z"/>
              <path fill-rule="evenodd" d="M14.5 3a1 1 0 0 1-1 1H13v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V4h-.5a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1H6a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1h3.5a1 1 0 0 1 1 1v1zM4.118 4 4 4.059V13a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1V4.059L11.882 4H4.118zM2.5 3V2h11v1h-11z"/>
            </svg>
          </button>
        </div>
        <div class="history-item-stats">
          <div class="history-item-stat">
            <span>💬 ${conv.messageCount} messages</span>
          </div>
        </div>
      </div>
    `).join('');
  }

  function getConversationPreview(conversation) {
    const firstUserMsg = conversation.messages.find(msg => msg.role === 'user');
    const firstAiMsg = conversation.messages.find(msg => msg.role === 'assistant');
    
    if (firstUserMsg && firstAiMsg) {
      return `You: ${firstUserMsg.content.substring(0, 50)}... AI: ${firstAiMsg.content.substring(0, 50)}...`;
    } else if (firstUserMsg) {
      return `You: ${firstUserMsg.content.substring(0, 100)}...`;
    }
    return 'Empty conversation';
  }

  // Expose bridge functions expected by QML
  window.setStatus = function(status, text) {
    ensureDom();
    if (!statusDot || !statusText) {
      // DOM not ready yet; retry shortly
      setTimeout(function() { window.setStatus(status, text); }, 20);
      return;
    }

    statusDot.className = 'status-dot';
    if (status === 'loading') {
      statusDot.classList.add('loading');
      isInitializing = true;
      isLoading = false;
      if (messageInput) messageInput.disabled = true;
      if (setupProgress) setupProgress.classList.add('visible');
    } else if (status === 'processing') {
      statusDot.classList.add('loading');
      isLoading = true;
      isInitializing = false;
      if (messageInput) messageInput.disabled = true;
    } else if (status === 'error') {
      statusDot.classList.add('error');
      isLoading = false;
      isInitializing = false;
      if (messageInput) messageInput.disabled = false;
      if (setupProgress) setupProgress.classList.remove('visible');
    } else if (status === 'ready') {
      isInitializing = false;
      isLoading = false;
      if (messageInput) messageInput.disabled = false;
      if (setupProgress) setupProgress.classList.remove('visible');
    }

    statusText.textContent = text;
    updateSendButton();
  };

  window.updateProgress = function(step, message, percent, speed) {
    ensureDom();
    if (!progressBar || !progressText) return;

    progressBar.style.width = percent + '%';

    const originalMessage = message || '';

    let derivedSpeed = (speed || '').trim();
    const speedBracketMatch = originalMessage.match(/\s*\[([^\]]+)\]\s*$/);
    if (!derivedSpeed && speedBracketMatch) {
      derivedSpeed = speedBracketMatch[1].trim();
    }

    let cleanedMessage = originalMessage
      .replace(/\s*\[[^\]]+\]\s*$/, '')
      .replace(/([0-9]+(?:\.[0-9]+)?\s*[KMGT]?B)\s*\/\s*([0-9]+(?:\.[0-9]+)?\s*[KMGT]?B)/gi, '$2');

    let displayMessage = cleanedMessage;
    if (derivedSpeed && derivedSpeed.trim() !== '') {
      displayMessage += '<br><span class="progress-speed">📡 ' + derivedSpeed + '</span>';
    }
    progressText.innerHTML = displayMessage;

    const steps = ['init', 'engine', 'service', 'model', 'complete'];
    const currentStepIndex = steps.indexOf(step);
    steps.forEach((stepName, index) => {
      const stepElement = document.getElementById('step-' + stepName);
      if (!stepElement) return;
      const icon = stepElement.querySelector('.step-icon');

      if (index < currentStepIndex) {
        stepElement.className = 'progress-step completed';
        icon.className = 'step-icon completed';
        icon.textContent = '✓';
      } else if (index === currentStepIndex) {
        stepElement.className = 'progress-step active';
        icon.className = 'step-icon active';
        if (stepName === 'init') icon.textContent = '1';
        else if (stepName === 'engine') icon.textContent = '2';
        else if (stepName === 'service') icon.textContent = '3';
        else if (stepName === 'model') icon.textContent = '4';
        else if (stepName === 'complete') icon.textContent = '✓';
      } else {
        stepElement.className = 'progress-step';
        icon.className = 'step-icon';
        if (stepName === 'init') icon.textContent = '1';
        else if (stepName === 'engine') icon.textContent = '2';
        else if (stepName === 'service') icon.textContent = '3';
        else if (stepName === 'model') icon.textContent = '4';
        else if (stepName === 'complete') icon.textContent = '✓';
      }
    });

    if (step === 'complete' && percent >= 100) {
      setTimeout(() => {
        if (setupProgress) setupProgress.classList.remove('visible');
        isInitializing = false;
        updateSendButton();
      }, 2000);
    }
  };

  window.addSetupLog = function(message) { console.log('Setup log:', message); };

  // Render message with avatar and collapsed thinking by default
  window.addMessage = function(role, text, thinking) {
    ensureDom();
    if (!chatMessages) {
      setTimeout(function() { window.addMessage(role, text, thinking); }, 20);
      return;
    }

    // Add to current conversation
    currentConversation.push({
      role: role,
      content: text,
      thinking: thinking || '',
      timestamp: new Date().toISOString()
    });

    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${role}`;

    const hasThinking = !!(thinking && thinking.length > 0);
    const roleLabel = role === 'user' ? 'YOU' : 'AI';
    const roleAlt = role === 'user' ? 'User' : 'AI';
    const avatarSrc = '../logo.png';

    const showThinkingUI = (role === 'assistant') && (hasThinking || isLoading);
    const sanitizedThinking = hasThinking ? escapeHtml(thinking).replace(/\n/g, '<br>') : '';
    const thinkingToggle = showThinkingUI ? '<div class="thinking-toggle" onclick="toggleThinking(this)">▶</div>' : '';
    const thinkingSummary = showThinkingUI ? '<div class="thinking-summary" onclick="toggleThinking(this)">💭 thinking...</div>' : '';
    const thinkingContent = hasThinking ? `<div class="thinking-content"><strong>💭 Thinking:</strong><br>${sanitizedThinking}</div>` : '';

    messageDiv.innerHTML = `
      <div class="message-bubble">
        <div class="message-header">
          <div class="message-role">
            <img class="role-avatar" src="${avatarSrc}" alt="${roleAlt}">
            <span class="role-text">${roleLabel}</span>
          </div>
          ${thinkingToggle}
        </div>
        ${thinkingSummary}
        ${thinkingContent}
        <div class="message-content"></div>
      </div>`;

    const contentDiv = messageDiv.querySelector('.message-content');
    if (role === 'assistant') {
      contentDiv.innerHTML = renderMarkdown(text);
    } else {
      contentDiv.textContent = text;
    }

    chatMessages.appendChild(messageDiv);
    chatMessages.scrollTop = chatMessages.scrollHeight;
  };

  // Update last assistant message; keep thinking collapsed unless user opens it
  window.updateMessage = function(text, thinking) {
    ensureDom();
    if (!chatMessages) return;

    const messages = chatMessages.querySelectorAll('.message.assistant');
    if (messages.length > 0) {
      const lastMessage = messages[messages.length - 1];
      const contentDiv = lastMessage.querySelector('.message-content');
      if (contentDiv) { 
        if (lastMessage.classList.contains('assistant')) {
          contentDiv.innerHTML = renderMarkdown(text);
        } else {
          contentDiv.textContent = text;
        }
        
        // Update current conversation
        if (currentConversation.length > 0) {
          const lastConvMessage = currentConversation[currentConversation.length - 1];
          if (lastConvMessage.role === 'assistant') {
            lastConvMessage.content = text;
            lastConvMessage.thinking = thinking || '';
          }
        }
      }

      if (thinking && thinking.length > 0) {
        const bubble = lastMessage.querySelector('.message-bubble');
        const header = lastMessage.querySelector('.message-header');

        // Ensure toggle exists
        if (header && !header.querySelector('.thinking-toggle')) {
          header.innerHTML += '<div class="thinking-toggle" onclick="toggleThinking(this)">▶</div>';
        }

        // Ensure summary exists
        let summaryDiv = bubble.querySelector('.thinking-summary');
        if (!summaryDiv) {
          summaryDiv = document.createElement('div');
          summaryDiv.className = 'thinking-summary';
          summaryDiv.textContent = '💭 thinking...';
          summaryDiv.setAttribute('onclick', 'toggleThinking(this)');
          bubble.insertBefore(summaryDiv, bubble.querySelector('.message-content'));
        }

        // Ensure content exists
        let thinkingDiv = bubble.querySelector('.thinking-content');
        if (!thinkingDiv) {
          thinkingDiv = document.createElement('div');
          thinkingDiv.className = 'thinking-content';
          bubble.insertBefore(thinkingDiv, bubble.querySelector('.message-content'));
        }

        // Sanitize and update content; keep collapsed by default
        const sanitized = escapeHtml(thinking).replace(/\n/g, '<br>');
        thinkingDiv.innerHTML = `<strong>💭 Thinking:</strong><br>${sanitized}`;
      }
      // Ensure summary exists during streaming even if no hidden thinking text
      if ((!thinking || thinking.length === 0) && isLoading) {
        const bubble = lastMessage.querySelector('.message-bubble');
        if (bubble && !bubble.querySelector('.thinking-summary')) {
          const summaryDiv = document.createElement('div');
          summaryDiv.className = 'thinking-summary';
          summaryDiv.textContent = '💭 thinking...';
          summaryDiv.setAttribute('onclick', 'toggleThinking(this)');
          bubble.insertBefore(summaryDiv, bubble.querySelector('.message-content'));
        }
      }
      // Ensure toggle arrow also appears during streaming even if no hidden thinking text yet
      if ((!thinking || thinking.length === 0) && isLoading) {
        const header2 = lastMessage.querySelector('.message-header');
        if (header2 && !header2.querySelector('.thinking-toggle')) {
          header2.innerHTML += '<div class="thinking-toggle" onclick="toggleThinking(this)">▶</div>';
        }
      }
    }
    chatMessages.scrollTop = chatMessages.scrollHeight;
  };

  window.toggleThinking = function(button) {
    const bubble = button.closest('.message-bubble');
    if (!bubble) return;
    const thinkingContent = bubble.querySelector('.thinking-content');
    if (!thinkingContent) return;
    const arrow = bubble.querySelector('.thinking-toggle');

    const isVisible = thinkingContent.classList.contains('visible');
    if (isVisible) {
      thinkingContent.classList.remove('visible');
      if (arrow) arrow.textContent = '▶';
    } else {
      thinkingContent.classList.add('visible');
      if (arrow) arrow.textContent = '▼';
    }
  };

  // Expose history functions to QML
  window.setHistoryData = function(data) {
    try {
      historyData = JSON.parse(data);
      renderHistoryList();
    } catch (e) {
      console.error('Failed to parse history data:', e);
      historyData = [];
    }
  };

  window.clearCurrentConversation = function() {
    currentConversation = [];
    if (chatMessages) {
      chatMessages.innerHTML = '';
    }
  };

  // Make functions globally accessible
  window.loadConversation = loadConversation;
  window.deleteConversation = deleteConversation;

  document.addEventListener('DOMContentLoaded', function() {
    cacheDom();
    initListeners();
    initHistoryElements();
    initHistoryListeners();
    updateSendButton();
    console.log('Dooms AI HTML Frontend initialized');
  });
})();