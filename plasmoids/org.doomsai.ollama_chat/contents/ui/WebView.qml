import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebEngine
import org.kde.plasma.core as PlasmaCore

Item {
    id: webViewRoot
    
    property alias webview: webview
    property var messageCallback: null
    
    Layout.fillWidth: true
    Layout.fillHeight: true

    WebEngineView {
        id: webview
        anchors.fill: parent
        url: Qt.resolvedUrl("chat.html")  // Load our local HTML file
        
        onJavaScriptConsoleMessage: function(level, message, lineNumber, sourceID) {
            console.log("WebView JS:", message)
            
            // Handle messages from HTML
            if (message.startsWith('SEND_MESSAGE:')) {
                const userMessage = message.replace('SEND_MESSAGE:', '')
                console.log("Received message from HTML:", userMessage)
                
                // Send to QML for processing
                if (webViewRoot.messageCallback) {
                    webViewRoot.messageCallback(userMessage)
                }
            }
        }
        
        onLoadingChanged: function(loadRequest) {
            if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                console.log("HTML loaded successfully!")
                
                // Inject JavaScript to handle communication
                runJavaScript(`
                    // Override the sendToQML function from HTML
                    window.sendToQML = function(message) {
                        console.log('SEND_MESSAGE:' + message);
                    };
                    
                    // Override qmlBridge.sendMessage
                    window.qmlBridge = {
                        sendMessage: function(message) {
                            console.log('SEND_MESSAGE:' + message);
                        }
                    };
                    
                    console.log('Dooms AI WebView initialized');
                `)
            } else if (loadRequest.status === WebEngineView.LoadFailedStatus) {
                console.error("Failed to load HTML file:", loadRequest.errorString)
            }
        }
        
        onFeaturePermissionRequested: function(securityOrigin, feature) {
            // Grant all permissions for local HTML
            grantFeaturePermission(securityOrigin, feature, true)
        }
        
        // WebEngine profile for local content
        WebEngineProfile {
            id: webProfile
            storageName: "dooms-ai-chat"
            offTheRecord: false
            httpCacheType: WebEngineProfile.DiskHttpCache
            persistentCookiesPolicy: WebEngineProfile.ForcePersistentCookies
        }
        
        profile: webProfile
        
        // WebEngine settings
        settings {
            allowWindowActivationFromJavaScript: true
            javascriptCanAccessClipboard: true
            javascriptCanOpenWindows: false
            javascriptCanPaste: true
            unknownUrlSchemePolicy: WebEngineSettings.AllowAllUnknownUrlSchemes
            playbackRequiresUserGesture: false
            focusOnNavigationEnabled: true
            screenCaptureEnabled: false
            pluginsEnabled: false
            // Force dark mode based on Plasma theme
            forceDarkMode: {
                const hex = PlasmaCore.Theme.backgroundColor.toString().substring(1);
                const r = parseInt(hex.substring(0, 2), 16);
                const g = parseInt(hex.substring(2, 4), 16);
                const b = parseInt(hex.substring(4, 6), 16);
                const luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
                return luma < 128;
            }
        }
    }
    
    // Loading indicator
    Rectangle {
        visible: webview.loading
        anchors.fill: parent
        color: "#000000"
        
        Column {
            anchors.centerIn: parent
            spacing: 20
            
            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: webview.loading
            }
            
            Text {
                text: "Loading Dooms AI..."
                color: "#00ffff"
                font.family: "monospace"
                font.pixelSize: 16
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
    
    // Error display
    Rectangle {
        visible: !webview.loading && webview.url.toString() === ""
        anchors.fill: parent
        color: "#000000"
        
        Column {
            anchors.centerIn: parent
            spacing: 20
            
            Text {
                text: "⚠️ WebEngine Error"
                color: "#ff0000"
                font.family: "monospace"
                font.pixelSize: 18
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: "Failed to load HTML interface.\nMake sure QtWebEngine is installed."
                color: "#ffffff"
                font.family: "monospace"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: "Install: sudo apt install qtwebengine5-dev"
                color: "#00ff00"
                font.family: "monospace"
                font.pixelSize: 10
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}