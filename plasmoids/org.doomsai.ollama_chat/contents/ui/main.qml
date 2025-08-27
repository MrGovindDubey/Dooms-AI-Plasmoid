import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami 2.20 as Kirigami
import QtCore

PlasmoidItem {
    id: root
    switchWidth: 450
    switchHeight: 600

    property bool initializing: true
    property bool setupDone: settings.setupDone
    property bool modelReady: false
    property string statusText: "Initializing…"
    property bool isLoading: false
    property var promptArray: []
    property string ollamaModel: "huihui_ai/qwen3-abliterated:8b"

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

    property string currentOp: ""
    property string currentBuffer: ""

    Component.onCompleted: {
        if (setupDone) {
            initializing = false
            modelReady = true
            statusText = "Ready"
        } else {
            setupTimer.start()
        }
    }

    Timer {
        id: setupTimer
        interval: 200
        repeat: false
        onTriggered: backend.checkAndSetup()
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
                if (currentOp === "setup") {
                    const lines = out.split(/\r?\n/).filter(l => l.length)
                    for (let i = 0; i < lines.length; ++i) setupLogModel.append({ text: lines[i] })
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

    function appendMessage(role, text, thinking) {
        conversationModel.append({ 
            role: role, 
            text: text, 
            thinking: thinking || "",
            showThinking: false
        })
    }

    function requestChat(prompt) {
        if (!prompt || initializing || isLoading) return
        appendMessage("user", prompt)
        promptArray.push({ role: "user", content: prompt, images: [] })
        isLoading = true
        statusText = "Processing"

        const oldLength = conversationModel.count
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
        xhr.onreadystatechange = function() {
            const objects = xhr.responseText.split('\n')
            let text = ''
            for (let i = 0; i < objects.length; ++i) {
                const line = objects[i]
                if (!line) continue
                try {
                    const obj = JSON.parse(line)
                    text += (obj && obj.message && obj.message.content) ? obj.message.content : ''
                } catch (e) {
                    // ignore partial JSON chunks
                }
            }
            if (text.length === 0) return
            
            // Parse thinking vs final response
            let thinkingContent = ""
            let finalContent = text
            let displayText = text
            
            if (text.includes('<thinking>') && text.includes('</thinking>')) {
                const thinkingMatch = text.match(/<thinking>([\s\S]*?)<\/thinking>/i)
                const afterThinking = text.split(/<\/thinking>/i)[1]
                if (thinkingMatch) {
                    thinkingContent = thinkingMatch[1].trim()
                    finalContent = afterThinking ? afterThinking.trim() : text
                    displayText = finalContent || "thinking..."
                }
            } else if (text.toLowerCase().includes('thinking:') || text.toLowerCase().includes('let me think')) {
                const lines = text.split('\n')
                let isThinkingSection = false
                let thinkingLines = []
                let responseLines = []
                
                for (let line of lines) {
                    if (line.toLowerCase().includes('thinking:') || line.toLowerCase().includes('let me think')) {
                        isThinkingSection = true
                        thinkingLines.push(line)
                    } else if (line.toLowerCase().includes('answer:') || line.toLowerCase().includes('response:')) {
                        isThinkingSection = false
                        responseLines.push(line)
                    } else if (isThinkingSection) {
                        thinkingLines.push(line)
                    } else {
                        responseLines.push(line)
                    }
                }
                
                if (thinkingLines.length > 0) {
                    thinkingContent = thinkingLines.join('\n').trim()
                    finalContent = responseLines.join('\n').trim()
                    displayText = finalContent || "thinking..."
                }
            }
            
            if (conversationModel.count === oldLength) {
                conversationModel.append({ 
                    name: "Assistant", 
                    role: "assistant", 
                    text: displayText,
                    thinking: thinkingContent,
                    showThinking: false
                })
            } else {
                const lastIdx = oldLength
                const last = conversationModel.get(lastIdx)
                last.text = displayText
                last.thinking = thinkingContent
                conversationModel.set(lastIdx, last)
            }
        }
        xhr.onload = function() {
            isLoading = false
            statusText = "Ready"
            const last = conversationModel.get(oldLength)
            const finalText = last ? last.text : ''
            if (finalText && finalText.length && finalText !== "thinking...") {
                promptArray.push({ role: "assistant", content: finalText, images: [] })
            }
        }
        xhr.onerror = function() {
            isLoading = false
            statusText = "Ready"
            appendMessage("assistant", "An error occurred.")
        }
        xhr.send(payload)
    }

    ListModel { id: conversationModel }
    ListModel { id: setupLogModel }

    fullRepresentation: Rectangle {
        color: "#000000"  // Pure black background
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // HEADER - Dark with neon accent
            Rectangle {
                Layout.fillWidth: true
                height: 50
                color: "#111111"  // Dark gray
                border.width: 1
                border.color: "#333333"
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    
                    Text {
                        text: "⚡ DOOMS AI"
                        color: "#00FFFF"  // Cyan neon
                        font.bold: true
                        font.pixelSize: 16
                        font.family: "monospace"
                        Layout.fillWidth: true
                    }
                    
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: initializing || isLoading ? "#FF6600" : "#00FF00"  // Orange/Green
                        
                        SequentialAnimation on opacity {
                            running: initializing || isLoading
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 500 }
                            NumberAnimation { to: 1.0; duration: 500 }
                        }
                    }
                    
                    Text {
                        text: statusText
                        color: "#CCCCCC"  // Light gray
                        font.pixelSize: 10
                        font.family: "monospace"
                    }
                }
            }

            // SETUP LOG - Terminal style
            Rectangle {
                visible: initializing
                Layout.fillWidth: true
                height: 100
                color: "#0A0A0A"  // Almost black
                border.width: 1
                border.color: "#333333"
                
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 5
                    
                    ListView {
                        model: setupLogModel
                        delegate: Text {
                            text: "$ " + model.text
                            color: "#00FF00"  // Matrix green
                            font.family: "monospace"
                            font.pixelSize: 9
                        }
                    }
                }
            }

            // CHAT AREA - Main conversation
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#000000"  // Pure black
                
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 5
                    
                    ListView {
                        id: chatView
                        model: conversationModel
                        spacing: 10
                        onCountChanged: positionViewAtEnd()
                        
                        delegate: Item {
                            width: chatView.width
                            height: messageRect.height + 10
                            
                            Rectangle {
                                id: messageRect
                                width: Math.min(messageContent.implicitWidth + 20, chatView.width * 0.8)
                                height: messageContent.implicitHeight + 20
                                
                                // Position: user right, AI left
                                anchors.right: model.role === "user" ? parent.right : undefined
                                anchors.left: model.role === "user" ? undefined : parent.left
                                anchors.rightMargin: model.role === "user" ? 10 : 0
                                anchors.leftMargin: model.role === "user" ? 0 : 10
                                
                                // Colors: user blue, AI dark gray
                                color: model.role === "user" ? "#0066CC" : "#1A1A1A"
                                border.width: 1
                                border.color: model.role === "user" ? "#0099FF" : "#444444"
                                radius: 10
                                
                                Column {
                                    id: messageContent
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 10
                                    spacing: 5
                                    
                                    // Header with role and thinking toggle
                                    Row {
                                        width: parent.width
                                        spacing: 5
                                        
                                        Text {
                                            text: model.role === "user" ? "👤 YOU" : "🤖 AI"
                                            color: "#FFFFFF"  // White
                                            font.bold: true
                                            font.pixelSize: 10
                                            font.family: "monospace"
                                        }
                                        
                                        // Thinking toggle button
                                        Rectangle {
                                            visible: model.role === "assistant" && model.thinking && model.thinking.length > 0
                                            width: 20
                                            height: 15
                                            color: thinkingMouse.containsMouse ? "#333333" : "#222222"
                                            border.width: 1
                                            border.color: "#666666"
                                            radius: 3
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: model.showThinking ? "▼" : "▶"
                                                color: "#CCCCCC"
                                                font.pixelSize: 8
                                            }
                                            
                                            MouseArea {
                                                id: thinkingMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: {
                                                    const item = conversationModel.get(index)
                                                    item.showThinking = !item.showThinking
                                                    conversationModel.set(index, item)
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Thinking content (collapsible)
                                    Rectangle {
                                        visible: model.role === "assistant" && model.showThinking && model.thinking && model.thinking.length > 0
                                        width: parent.width
                                        height: thinkingText.implicitHeight + 10
                                        color: "#0A0A0A"
                                        border.width: 1
                                        border.color: "#666666"
                                        radius: 5
                                        
                                        Text {
                                            id: thinkingText
                                            anchors.fill: parent
                                            anchors.margins: 5
                                            text: "💭 " + (model.thinking || "")
                                            color: "#888888"  // Gray
                                            font.italic: true
                                            font.pixelSize: 9
                                            font.family: "monospace"
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                    
                                    // Main message text
                                    Text {
                                        width: parent.width
                                        text: model.text
                                        color: "#FFFFFF"  // White
                                        font.pixelSize: 11
                                        font.family: "monospace"
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // INPUT AREA - Bottom section
            Rectangle {
                Layout.fillWidth: true
                height: 60
                color: "#111111"  // Dark gray
                border.width: 1
                border.color: "#333333"
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8
                    
                    // Text input
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "#1A1A1A"  // Darker gray
                        border.width: 1
                        border.color: inputArea.activeFocus ? "#0099FF" : "#444444"
                        radius: 5
                        
                        TextArea {
                            id: inputArea
                            anchors.fill: parent
                            anchors.margins: 5
                            color: "#FFFFFF"  // White text
                            font.pixelSize: 11
                            font.family: "monospace"
                            placeholderText: initializing ? "Setting up..." : (isLoading ? "Processing..." : "Type message...")
                            placeholderTextColor: "#666666"
                            background: Rectangle { color: "transparent" }
                            wrapMode: TextArea.Wrap
                            enabled: !initializing && !isLoading
                            
                            Keys.onReturnPressed: {
                                if (!(event.modifiers & Qt.ShiftModifier)) {
                                    event.accepted = true
                                    const msg = inputArea.text.trim()
                                    if (msg.length) {
                                        inputArea.text = ""
                                        requestChat(msg)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Send button
                    Rectangle {
                        width: 80
                        Layout.fillHeight: true
                        color: sendMouse.containsMouse ? "#0099FF" : "#0066CC"
                        border.width: 1
                        border.color: "#0099FF"
                        radius: 5
                        enabled: !initializing && !isLoading && inputArea.text.length > 0
                        opacity: enabled ? 1.0 : 0.5
                        
                        Text {
                            anchors.centerIn: parent
                            text: "⮕ SEND"
                            color: "#FFFFFF"
                            font.bold: true
                            font.pixelSize: 10
                            font.family: "monospace"
                        }
                        
                        MouseArea {
                            id: sendMouse
                            anchors.fill: parent
                            enabled: parent.enabled
                            hoverEnabled: true
                            onClicked: {
                                const msg = inputArea.text.trim()
                                if (msg.length) {
                                    inputArea.text = ""
                                    requestChat(msg)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    QtObject {
        id: backend

        function checkAndSetup() {
            statusText = "Checking"
            initializing = true
            setupLogModel.clear()
            runCommand("setup", "bash", [pkgFile("../scripts/setup.sh"), root.ollamaModel])
        }

        function ask(prompt) {
            if (!modelReady) return
            statusText = "Thinking"
            initializing = true
            runCommand("ask", "bash", [pkgFile("../scripts/ask.sh"), root.ollamaModel, prompt])
        }

        function _onCommandFinished(op, code, stdout) {
            if (op === "setup") {
                if (code !== 0) {
                    statusText = "Setup failed"
                    initializing = false
                    modelReady = false
                    return
                }
                modelReady = true
                initializing = false
                statusText = "Ready"
                settings.setupDone = true
            } else if (op === "ask") {
                initializing = false
                if (code !== 0) {
                    appendMessage("assistant", "Error during inference.")
                } else {
                    appendMessage("assistant", stdout)
                }
            }
        }
    }

    Settings {
        id: settings
        category: "org.doomsai.ollama_chat"
        property bool setupDone: false
    }
}