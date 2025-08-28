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
    property string statusText: "Initializing"
    property bool isLoading: false
    property var promptArray: []
    property string ollamaModel: "huihui_ai/qwen3-abliterated:8b"
    property var webviewItem: null
    property bool webviewReady: false

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
                const escapedText = text.replace(/'/g, "\\'").replace(/"/g, '\\"').replace(/\n/g, '\\n')
                const escapedThinking = (thinking || "").replace(/'/g, "\\'").replace(/"/g, '\\"').replace(/\n/g, '\\n')
                root.webviewItem.runJavaScript("if (window.addMessage) window.addMessage('" + role + "', '" + escapedText + "', '" + escapedThinking + "');")
            } catch (e) {
                console.warn("Failed to add message:", e)
            }
        }
    }

    function updateHtmlMessage(text, thinking) {
        if (root.webviewItem && root.webviewReady) {
            try {
                const escapedText = text.replace(/'/g, "\\'").replace(/"/g, '\\"').replace(/\n/g, '\\n')
                const escapedThinking = (thinking || "").replace(/'/g, "\\'").replace(/"/g, '\\"').replace(/\n/g, '\\n')
                root.webviewItem.runJavaScript("if (window.updateMessage) window.updateMessage('" + escapedText + "', '" + escapedThinking + "');")
            } catch (e) {
                console.warn("Failed to update message:", e)
            }
        }
    }

    property string currentOp: ""
    property string currentBuffer: ""

    Component.onCompleted: {
        console.log("Dooms AI Widget starting...")
        root.expanded = true
        
        // Setup will start when WebView is ready
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
            settings.setupDone = true
            updateHtmlStatus("ready", "Ready")
            addHtmlMessage("assistant", "Hello! I'm Dooms AI. Setup complete! I'm ready to chat with you. How can I help you today?", "")
        }
        
        onSetupFailed: function(error) {
            console.error("Setup failed via progress monitor:", error)
            statusText = "Setup failed"
            initializing = false
            modelReady = false
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
                    
                    // Parse thinking vs final response
                    let thinkingContent = ""
                    let finalContent = currentText
                    let displayText = currentText
                    
                    if (currentText.includes('<thinking>') && currentText.includes('</thinking>')) {
                        const thinkingMatch = currentText.match(/<thinking>([\s\S]*?)<\/thinking>/i)
                        const afterThinking = currentText.split(/<\/thinking>/i)[1]
                        if (thinkingMatch) {
                            thinkingContent = thinkingMatch[1].trim()
                            finalContent = afterThinking ? afterThinking.trim() : currentText
                            displayText = finalContent || "thinking..."
                        }
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
            updateHtmlStatus("error", "Connection failed")
            addHtmlMessage("assistant", "Error: Could not connect to AI service. Please check if it's running.", "")
        }
        
        xhr.send(payload)
    }

    ListModel { id: setupLogModel }

    // Compact representation (icon only)
    compactRepresentation: Item {
        Layout.fillWidth: false
        Layout.fillHeight: false
        Layout.minimumWidth: Kirigami.Units.iconSizes.small
        Layout.minimumHeight: Kirigami.Units.iconSizes.small
        
        Kirigami.Icon {
            anchors.fill: parent
            source: "applications-internet"
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
            active: true
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
                        
                        // Set initial status
                        updateHtmlStatus("loading", "Initializing")
                        
                        // Set up message callback for user input
                        item.messageCallback = function(message) {
                            console.log("User message from HTML:", message)
                            requestChat(message)
                        }
                        
                        // Now that WebView is ready, start the setup check
                        quickCheckTimer.start()
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
            updateHtmlStatus("loading", "Checking AI system...")
            
            // Check if Ollama is running and model exists
            runCommand("quickcheck", "bash", ["-c", "curl -s http://127.0.0.1:11434/api/tags | grep -q '" + root.ollamaModel + "' && echo 'READY' || echo 'SETUP_NEEDED'"])
        }

        function checkAndSetup() {
            console.log("Starting auto-setup with live progress monitoring...")
            statusText = "Setting up"
            initializing = true
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
                    settings.setupDone = true
                    updateHtmlStatus("ready", "Ready")
                    addHtmlMessage("assistant", "Hello! I'm Dooms AI. I'm ready to chat with you. How can I help you today?", "")
                } else {
                    console.log("Quick check: Setup needed")
                    setupTimer.start()
                }
                return
            }
        }
    }

    Settings {
        id: settings
        category: "org.doomsai.ollama_chat"
        property bool setupDone: false
    }
}