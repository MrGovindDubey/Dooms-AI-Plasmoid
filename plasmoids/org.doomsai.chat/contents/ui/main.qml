import QtQuick
import QtQuick.Layouts
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.plasma5support as Plasma5Support
import QtCore

PlasmoidItem {
    id: root
    switchWidth: Kirigami.Units.gridUnit * 28
    switchHeight: Kirigami.Units.gridUnit * 39

    property bool initializing: true
    property bool setupDone: settings.setupDone
    property bool modelReady: false
    property string stat    property string statusState: "loading"
    property bool isLoading: false
    property bool startupInitiated: false
    property var promptArray: []
    property string ollamaModel: "huihui_ai/qwen3-abliterated:8b"
    property var webviewItem: null
    property bool webviewReady: false
    property string historyDir: ""

    function shellEscape(str) {
        return "'" + String(str).replace(/'/g, "'\\''") + "'";
    }

    function pkgFile(rel) {
        var url = Qt.resolvedUrl(rel)
        return url.toString().replace(/^file:\/\//, "")
    }

    function runCommand(op, prog, args) {
        currentOp = op
        currentBuffer = ""
        const parts = [prog].concat(args || [])
        const cmd = parts.map(shellEscape).join(" ")
        exec.connectSource(cmd)
    }

    function updateHtmlStatus(status, text) {
        if (root.webviewItem && root.webviewReady) {
            try {
                root.webviewItem.runJavaScript("if (window.setStatus) window.setStatus('" + status + "', '" + text + "');")
            } catch (e) {
                console.warn("Failed to update HTML status:", e)
            }
        }
    }

    function addHtmlSetupLog(message) {
        if (root.webviewItem && root.webviewReady) {
            try {
                const escapedMessage = message.replace(/'/g, "\\'").replace(/"/g, '\\"')
                root.webviewItem.runJavaScript("if (window.addSetupLog) window.addSetupLog('" + escapedMessage + "');")
            } catch (e) {
                console.warn("Failed to add setup log:", e)
            }
        }
    }

    function updateHtmlProgress(step, message, percent, speed) {
        if (root.webviewItem && root.webviewReady) {
            try {
                const escapedMessage = message.replace(/'/g, "\\'").replace(/"/g, '\\"')
                const escapedSpeed = (speed || "").replace(/'/g, "\\'").replace(/"/g, '\\"')
                root.webviewItem.runJavaScript("if (window.updateProgress) window.updateProgress('" + step + "', '" + escapedMessage + "', " + percent + ", '" + escapedSpeed + "');")
            } catch (e) {
                console.warn("Failed to update progress:", e)
            }
        }
    }

    function addHtmlMessage(role, text, thinking) {
        if (root.webviewItem && root.webviewReady) {
            try {
                const roleJson = JSON.stringify(role)
                const textJson = JSON.stringify(text || "")
                const thinkingJson = JSON.stringify(thinking || "")
                root.webviewItem.runJavaScript("if (window.addMessage) window.addMessage(" + roleJson + ", " + textJson + ", " + thinkingJson + ");")
            } catch (e) {
                console.warn("Failed to add message:", e)
            }
        }
    }

    function updateHtmlMessage(text, thinking) {
        if (root.webviewItem && root.webviewReady) {
            try {
                const textJson = JSON.stringify(text || "")
                const thinkingJson = JSON.stringify(thinking || "")
                root.webviewItem.runJavaScript("if (window.updateMessage) window.updateMessage(" + textJson + ", " + thinkingJson + ");")
            } catch (e) {
                console.warn("Failed to update message:", e)
            }
        }
    }

    property string currentOp: ""
    property string currentBuffer: ""

    Component.onCompleted: {
    console.log("Dooms AI Widget starting...")
    
    // Initialize history directory
    initializeHistoryDirectory()
    
    // Kick off backend quick check regardless of WebView state (will update UI when ready)
    if (!startupInitiated) {
        startupInitiated = true
        quickCheckTimer.start()
    }
    }

    Timer {
        id: quickCheckTimer
        interval: 500
        repeat: false
        onTriggered: backend.quickCheck()
    }

    Timer {
        id: setupTimer
        interval: 1000
        repeat: false
        onTriggered: backend.checkAndSetup()
    }

    // Progress Monitor Component
    ProgressMonitor {
        id: progressMonitor
        parentRoot: root
        
        onProgressUpdated: function(step, message, percent, speed) {
            updateHtmlProgress(step, message, percent, speed)
        }
        
        onSetupCompleted: {
            console.log("Setup completed via progress monitor")
            modelReady = true
            initializing = false
            statusText = "Ready"
            statusState = "ready"
            settings.setupDone = true
            updateHtmlStatus("ready", "Ready")
            addHtmlMessage("assistant", "Hello! I'm Dooms AI. Setup complete! I'm ready to chat with you. How can I help you today?", "")
        }
        
        onSetupFailed: function(error) {
            console.error("Setup failed via progress monitor:", error)
            statusText = "Setup failed"
            initializing = false
            modelReady = false
            statusState = "error"
            updateHtmlStatus("error", "Setup failed: " + error)
        }
    }

    Plasma5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: function(source, data) {
            const out = data["stdout"] || ""
            const err = data["stderr"] || ""
            const exitCode = data["exit code"]
            if (out) {
                currentBuffer += out
                if (currentOp === "quickcheck") {
                    // Don't show quickcheck output in setup log
                }
            }
            if (err) console.warn("[" + currentOp + "]", err)
            if (exitCode !== undefined) {
                exec.disconnectSource(source)
                backend._onCommandFinished(currentOp, exitCode, currentBuffer.trim())
                currentOp = ""
                currentBuffer = ""
            }
        }
    }

    function requestChat(prompt) {
        if (!prompt || initializing || isLoading) return
        
        console.log("Processing chat request:", prompt)
        
        // Add user message to HTML
        addHtmlMessage("user", prompt, "")
        
        promptArray.push({ role: "user", content: prompt, images: [] })
        isLoading = true
        statusText = "Processing"
        statusState = "processing"
        updateHtmlStatus("processing", "Processing")

        const url = 'http://127.0.0.1:11434/api/chat'
        const payload = JSON.stringify({
            model: root.ollamaModel,
            keep_alive: "5m",
            options: {},
            messages: promptArray
        })

        let xhr = new XMLHttpRequest()
        xhr.open('POST', url, true)
        xhr.setRequestHeader('Content-Type', 'application/json')
        
        let fullResponse = ""
        let hasAddedAssistantMessage = false
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.LOADING || xhr.readyState === XMLHttpRequest.DONE) {
                const objects = xhr.responseText.split('\n')
                let currentText = ''
                
                for (let i = 0; i < objects.length; ++i) {
                    const line = objects[i].trim()
                    if (!line) continue
                    try {
                        const obj = JSON.parse(line)
                        if (obj && obj.message && obj.message.content) {
                            currentText += obj.message.content
                        }
                    } catch (e) {
                        // ignore partial JSON chunks
                    }
                }
                
                if (currentText.length > 0) {
                    fullResponse = currentText
                    
                    // Parse thinking vs final response (support <thinking> and <think>)
                    let thinkingContent = ""
                    let finalContent = currentText
                    let displayText = currentText

                    const thinkBlockRegex = /<(thinking|think)>[\s\S]*?<\/(thinking|think)>/i
                    const thinkCaptureRegex = /<(thinking|think)>([\s\S]*?)<\/(thinking|think)>/i

                    if (thinkBlockRegex.test(currentText)) {
                        const m = currentText.match(thinkCaptureRegex)
                        if (m) {
                            thinkingContent = (m[2] || "").trim()
                        }
                        const withoutThink = currentText.replace(thinkBlockRegex, "").trim()
                        finalContent = withoutThink.length ? withoutThink : currentText
                        displayText = withoutThink.length ? withoutThink : "thinking..."
                    }
                    
                    // Update HTML with live response
                    if (!hasAddedAssistantMessage) {
                        addHtmlMessage("assistant", displayText, thinkingContent)
                        hasAddedAssistantMessage = true
                    } else {
                        updateHtmlMessage(displayText, thinkingContent)
                    }
                }
            }
        }
        
        xhr.onload = function() {
            console.log("Chat response completed")
            isLoading = false
            statusText = "Ready"
            statusState = "ready"
            updateHtmlStatus("ready", "Ready")
            
            // Add to conversation history
            if (fullResponse && fullResponse.length) {
                promptArray.push({ role: "assistant", content: fullResponse, images: [] })
            }
        }
        
        xhr.onerror = function() {
            console.error("Chat request failed")
            isLoading = false
            statusText = "Error"
            statusState = "error"
            updateHtmlStatus("error", "Connection failed")
            addHtmlMessage("assistant", "Error: Could not connect to AI service. Please check if it's running.", "")
        }
        
        xhr.send(payload)
    }

    // History Management Functions
    function initializeHistoryDirectory() {
        // Set history directory path using environment variable
        runCommand("get_home_dir", "bash", ["-c", "echo $HOME"])
    }

    function saveConversationHistory(conversationData) {
        if (!conversationData || !conversationData.id) {
            console.error("Invalid conversation data for saving")
            return
        }

        const filename = conversationData.id + ".json"
        const filepath = historyDir + "/" + filename
        const jsonData = JSON.stringify(conversationData, null, 2)
        
        // Escape the JSON data for shell command
        const escapedData = jsonData.replace(/'/g, "'\\''")
        
        // Save to file using echo command
        runCommand("save_history", "bash", ["-c", "echo '" + escapedData + "' > '" + filepath + "'"])
        console.log("Conversation saved:", filename)
    }

    function loadConversationHistory() {
        // List all JSON files in history directory
        runCommand("load_history", "bash", ["-c", "find '" + historyDir + "' -name '*.json' -type f 2>/dev/null | head -50"])
    }

    function deleteConversationHistory(conversationId) {
        if (!conversationId) return
        
        const filename = conversationId + ".json"
        const filepath = historyDir + "/" + filename
        
        runCommand("delete_history", "rm", ["-f", filepath])
        console.log("Conversation deleted:", filename)
    }

    function clearAllHistory() {
        runCommand("clear_history", "bash", ["-c", "rm -f '" + historyDir + "'/*.json"])
        console.log("All history cleared")
    }

    function sendHistoryToHtml(historyArray) {
        if (root.webviewItem && root.webviewReady) {
            try {
                const escapedData = JSON.stringify(historyArray).replace(/'/g, "\\'").replace(/"/g, '\\"')
                root.webviewItem.runJavaScript("if (window.setHistoryData) window.setHistoryData('" + escapedData + "');")
            } catch (e) {
                console.warn("Failed to send history to HTML:", e)
            }
        }
    }

    function clearCurrentConversation() {
        promptArray = []
        if (root.webviewItem && root.webviewReady) {
            try {
                root.webviewItem.runJavaScript("if (window.clearCurrentConversation) window.clearCurrentConversation();")
            } catch (e) {
                console.warn("Failed to clear current conversation in HTML:", e)
            }
        }
    }

    function loadSpecificConversation(conversationId) {
        if (!conversationId) return
        
        const filename = conversationId + ".json"
        const filepath = historyDir + "/" + filename
        
        runCommand("load_specific_conversation", "cat", [filepath])
    }

    ListModel { id: setupLogModel }

    // Compact representation (icon only)
    compactRepresentation: Item {
        id: compactRoot
        // Use panel icon size when available for perfect fit; fallback to a sensible size
        property int panelIconSize: (PlasmaCore.Units && PlasmaCore.Units.iconSizeHints && PlasmaCore.Units.iconSizeHints.panel)
                                     ? PlasmaCore.Units.iconSizeHints.panel
                                     : Kirigami.Units.iconSizes.medium
        implicitWidth: panelIconSize
        implicitHeight: panelIconSize

        Kirigami.Icon {
            anchors.fill: parent
            anchors.margins: Math.floor(compactRoot.panelIconSize * 0.05)
            source: Qt.resolvedUrl("../logo.svg")
            active: compactMouse.containsMouse
        }

        MouseArea {
            id: compactMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }

    // Full representation (WebView)
    fullRepresentation: ColumnLayout {
        id: mainLayout
        spacing: 0
        Layout.minimumWidth: Kirigami.Units.gridUnit * 28
        Layout.minimumHeight: Kirigami.Units.gridUnit * 39

        // WebView loader
        Loader {
            id: webviewLoader
            active: root.expanded
            asynchronous: true
            source: "WebView.qml"
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            onStatusChanged: {
                if (status === Loader.Error) {
                    console.error("Failed to load WebView.qml")
                } else if (status === Loader.Ready) {
                    console.log("WebView loaded successfully")
                    root.webviewItem = item.webview
                    
                    // Set up message handling
                    if (item && item.webview) {
                        // Mark WebView as ready
                        root.webviewReady = true
                        
                        // Pass root reference to WebView
                        item.rootItem = root
                        
                        // Reflect current status into HTML
                        updateHtmlStatus(statusState, statusText)
                        
                        // Set up message callback for user input
                        item.messageCallback = function(message) {
                            console.log("User message from HTML:", message)
                            requestChat(message)
                        }
                        
                        // Now that WebView is ready, start the setup check (only once)
                        if (!startupInitiated) {
                            startupInitiated = true
                            quickCheckTimer.start()
                        }
                    }
                }
            }
        }
    }

    QtObject {
        id: backend

        function quickCheck() {
            console.log("Quick checking AI system...")
            statusText = "Checking"
            initializing = true
            statusState = "loading"
            updateHtmlStatus("loading", "Checking AI system...")
            
            // Check if Ollama is running and model exists
            runCommand("quickcheck", "bash", ["-c", "curl -s http://127.0.0.1:11434/api/tags | grep -q '" + root.ollamaModel + "' && echo 'READY' || echo 'SETUP_NEEDED'"])
        }

        function checkAndSetup() {
            console.log("Starting auto-setup with live progress monitoring...")
            statusText = "Setting up"
            initializing = true
            statusState = "loading"
            updateHtmlStatus("loading", "Setting up AI system")
            
            setupLogModel.clear()
            
            // Use the new progress monitor instead of direct command execution
            progressMonitor.startSetup(root.ollamaModel)
        }

        function _onCommandFinished(op, code, stdout) {
            if (op === "quickcheck") {
                if (stdout.includes("READY")) {
                    console.log("Quick check: Everything ready")
                    modelReady = true
                    initializing = false
                    statusText = "Ready"
                    statusState = "ready"
                    settings.setupDone = true
                    updateHtmlStatus("ready", "Ready")
                    addHtmlMessage("assistant", "Hello! I'm Dooms AI. I'm ready to chat with you. How can I help you today?", "")
                } else {
                    console.log("Quick check: Setup needed")
                    setupTimer.start()
                }
                return
            } else if (op === "get_home_dir") {
                if (code === 0 && stdout) {
                    const homeDir = stdout.trim()
                    historyDir = homeDir + "/.local/share/plasma/plasmoids/org.doomsai.chat/history"
                    console.log("History directory set to:", historyDir)
                    
                    // Create history directory if it doesn't exist
                    runCommand("create_history_dir", "mkdir", ["-p", historyDir])
                } else {
                    console.warn("Failed to get home directory")
                }
                return
            } else if (op === "create_history_dir") {
                if (code === 0) {
                    console.log("History directory created successfully")
                } else {
                    console.warn("Failed to create history directory")
                }
                return
            } else if (op === "save_history") {
                if (code === 0) {
                    console.log("Conversation saved successfully")
                } else {
                    console.warn("Failed to save conversation")
                }
                return
            } else if (op === "load_history") {
                if (code === 0 && stdout) {
                    // Process the list of history files
                    const historyFiles = stdout.split('\n').filter(f => f.trim().length > 0)
                    loadHistoryFiles(historyFiles)
                } else {
                    console.log("No history files found or error loading history")
                    sendHistoryToHtml([])
                }
                return
            } else if (op === "delete_history") {
                if (code === 0) {
                    console.log("Conversation deleted successfully")
                    // Reload history after deletion
                    loadConversationHistory()
                } else {
                    console.warn("Failed to delete conversation")
                }
                return
            } else if (op === "clear_history") {
                if (code === 0) {
                    console.log("All history cleared successfully")
                    sendHistoryToHtml([])
                } else {
                    console.warn("Failed to clear history")
                }
                return
            } else if (op.startsWith("load_history_file_")) {
                // Handle individual history file loading
                const filename = op.replace("load_history_file_", "")
                if (code === 0 && stdout) {
                    try {
                        const conversationData = JSON.parse(stdout)
                        backend.historyData = backend.historyData || []
                        backend.historyData.push(conversationData)
                        
                        // Check if this is the last file to load
                        backend.loadedFiles = (backend.loadedFiles || 0) + 1
                        if (backend.loadedFiles >= backend.totalFiles) {
                            // Sort by timestamp (newest first)
                            backend.historyData.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))
                            sendHistoryToHtml(backend.historyData)
                            backend.historyData = []
                            backend.loadedFiles = 0
                            backend.totalFiles = 0
                        }
                    } catch (e) {
                        console.warn("Failed to parse history file:", filename, e)
                    }
                }
                return
            } else if (op === "load_specific_conversation") {
                if (code === 0 && stdout) {
                    try {
                        const conversationData = JSON.parse(stdout)
                        console.log("Loading specific conversation:", conversationData.title)
                        
                        // Clear current conversation
                        clearCurrentConversation()
                        
                        // Load conversation messages into promptArray
                        promptArray = []
                        if (conversationData.messages) {
                            conversationData.messages.forEach(function(msg) {
                                promptArray.push({
                                    role: msg.role,
                                    content: msg.content,
                                    images: []
                                })
                            })
                        }
                        
                        console.log("Conversation loaded with", promptArray.length, "messages")
                    } catch (e) {
                        console.error("Failed to parse specific conversation:", e)
                    }
                } else {
                    console.warn("Failed to load specific conversation")
                }
                return
            }
        }

        function loadHistoryFiles(filePaths) {
            if (!filePaths || filePaths.length === 0) {
                sendHistoryToHtml([])
                return
            }

            backend.historyData = []
            backend.loadedFiles = 0
            backend.totalFiles = filePaths.length

            // Load each history file
            filePaths.forEach(function(filepath, index) {
                const filename = filepath.split('/').pop()
                runCommand("load_history_file_" + filename, "cat", [filepath])
            })
        }
    }

    Settings {
        id: settings
        category: "org.doomsai.chat"
        property bool setupDone: false
    }
}