// Dooms AI Chat - External Script
(function() {
  let isInitializing = true;
  let isLoading = false;

  // DOM elements (queried after DOMContentLoaded)
  let statusDot, statusText, setupProgress, progressBar, progressText,
      chatMessages, messageInput, sendButton, githubLink;

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

    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${role}`;

    const hasThinking = !!(thinking && thinking.length > 0);
    const roleLabel = role === 'user' ? 'YOU' : 'AI';
    const roleAlt = role === 'user' ? 'User' : 'AI';
    const avatarSrc = '../logo.png';

    const thinkingToggle = hasThinking ? '<div class="thinking-toggle" onclick="toggleThinking(this)">▶</div>' : '';
    const thinkingContent = hasThinking ? `<div class="thinking-content"><strong>💭 Thinking:</strong><br>${thinking}</div>` : '';

    messageDiv.innerHTML = `
      <div class="message-bubble">
        <div class="message-header">
          <div class="message-role">
            <img class="role-avatar" src="${avatarSrc}" alt="${roleAlt}">
            <span class="role-text">${roleLabel}</span>
          </div>
          ${thinkingToggle}
        </div>
        ${thinkingContent}
        <div class="message-content"></div>
      </div>`;

    const contentDiv = messageDiv.querySelector('.message-content');
    contentDiv.textContent = text;

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
      if (contentDiv) { contentDiv.textContent = text; }

      if (thinking && thinking.length > 0) {
        let thinkingDiv = lastMessage.querySelector('.thinking-content');
        if (!thinkingDiv) {
          const header = lastMessage.querySelector('.message-header');
          if (header && !header.querySelector('.thinking-toggle')) {
            header.innerHTML += '<div class="thinking-toggle" onclick="toggleThinking(this)">▶</div>';
          }
          thinkingDiv = document.createElement('div');
          thinkingDiv.className = 'thinking-content';
          lastMessage.querySelector('.message-bubble').insertBefore(
            thinkingDiv, lastMessage.querySelector('.message-content')
          );
        }
        // Do not auto-expand; keep collapsed by default
        thinkingDiv.innerHTML = `<strong>💭 Thinking:</strong><br>${thinking}`;
      }
    }
    chatMessages.scrollTop = chatMessages.scrollHeight;
  };

  window.toggleThinking = function(button) {
    const thinkingContent = button.closest('.message-bubble').querySelector('.thinking-content');
    if (!thinkingContent) return;
    if (thinkingContent.classList.contains('visible')) {
      thinkingContent.classList.remove('visible');
      button.textContent = '▶';
    } else {
      thinkingContent.classList.add('visible');
      button.textContent = '▼';
    }
  };

  document.addEventListener('DOMContentLoaded', function() {
    cacheDom();
    initListeners();
    updateSendButton();
    console.log('Dooms AI HTML Frontend initialized');
  });
})();
