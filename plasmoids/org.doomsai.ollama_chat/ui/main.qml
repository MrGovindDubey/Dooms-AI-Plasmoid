end import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami 2.20 as Kirigami

// Plasma 6 uses Qt6; using compatibility import versions. Adjust at install time if needed.

Item {
    id: root
    width: 420
    height: 560

    property bool initializing: true
    property bool modelReady: false
    property string statusText: "Setting up…"
    property string ollamaModel: "huihui_ai/qwen3-abliterated:latest"

    signal sendMessage(string text)

    Component.onCompleted: {
        // Kick off the background setup
        setupTimer.start()
    }

    Timer {
        id: setupTimer
        interval: 200
        repeat: false
        onTriggered: {
            backend.checkAndSetup()
        }
    }

    // Backend interface via DBus/Command helper
    Loader {
        id: backendLoader
        active: true
        source: "qrc:/plasmahelper/Backend.qml"
        asynchronous: true
        onStatusChanged: if (status === Loader.Error) console.error("Backend load error", errorString())
    }

    function appendMessage(role, text) {
        conversationModel.append({ role: role, text: text })
    }

    ListModel { id: conversationModel }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        Kirigami.InlineMessage {
            id: infoMsg
            visible: initializing
            text: statusText
            type: Kirigami.MessageType.Information
            Layout.fillWidth: true
        }

        ListView {
            id: chatView
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: conversationModel
            delegate: Kirigami.BasicListItem {
                width: chatView.width
                label: model.role === "user" ? "You" : "AI"
                subtitle: model.text
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            TextField {
                id: inputField
                Layout.fillWidth: true
                placeholderText: initializing ? "Setting up…" : "Type a message"
                enabled: !initializing
                onAccepted: sendButton.clicked()
            }
            Button {
                id: sendButton
                text: "Send"
                enabled: !initializing && inputField.text.length > 0
                onClicked: {
                    const msg = inputField.text
                    inputField.text = ""
                    appendMessage("user", msg)
                    backend.ask(msg)
                }
            }
        }
    }

    // Provide a minimal JS-driven backend using the command helper
    QtObject {
        id: backend

        function run(cmd, args, onFinished) {
            // Plasma JS environment does not allow arbitrary process spawn directly.
            // We leverage the KIO/ScriptExecutor helper via a tiny shell script shipped with the Plasma package.
            // For development preview, we attempt to call a helper executable installed with the plasmoid.
            var service = backendLoader.item
            if (!service) {
                console.error("Backend service not available")
                return
            }
            service.runCommand(cmd, args, onFinished)
        }

        function checkAndSetup() {
            statusText = "Checking…"
            initializing = true
            run("bash", [ plasmoid.file("scripts/setup.sh"), root.ollamaModel ], function(exitCode, stdout, stderr) {
                if (exitCode !== 0) {
                    statusText = "Setup failed. Open details in log (plasmoidviewer)"
                    console.error("Setup failed:", stderr)
                    initializing = false
                    modelReady = false
                    return
                }
                statusText = "Ready."
                initializing = false
                modelReady = true
            })
        }

        function ask(prompt) {
            if (!modelReady) return
            statusText = "Thinking…"
            initializing = true
            run("bash", [ plasmoid.file("scripts/ask.sh"), root.ollamaModel, prompt ], function(exitCode, stdout, stderr) {
                initializing = false
                if (exitCode !== 0) {
                    appendMessage("assistant", "An error occurred.")
                } else {
                    appendMessage("assistant", stdout)
                }
            })
        }
    }
}
