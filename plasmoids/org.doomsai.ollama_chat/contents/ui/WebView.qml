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
    property var rootItem: null
    
    Layout.fillWidth: true
    Layout.fillHeight: true

    WebEngineView {
        id: webview
        anchors.fill: parent
        url: Qt.resolvedUrl("chat.html?v=10")  // Load our local HTML file with cache-busting
        
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
            } else if (message.startsWith('SAVE_HISTORY:')) {
                const conversationData = message.replace('SAVE_HISTORY:', '')
                console.log("Save history request from HTML")
                
                try {
                    const data = JSON.parse(conversationData)
                    // The data already contains the messages from HTML
                    // Just pass it to the root for saving
                    if (webViewRoot.rootItem) {
                        webViewRoot.rootItem.saveConversationHistory(data)
                    }
                } catch (e) {
                    console.error("Failed to parse conversation data:", e)
                }
            } else if (message.startsWith('LOAD_HISTORY:')) {
                console.log("Load history request from HTML")
                if (webViewRoot.rootItem) {
                    webViewRoot.rootItem.loadConversationHistory()
                }
            } else if (message.startsWith('DELETE_HISTORY:')) {
                const conversationId = message.replace('DELETE_HISTORY:', '')
                console.log("Delete history request from HTML:", conversationId)
                if (webViewRoot.rootItem) {
                    webViewRoot.rootItem.deleteConversationHistory(conversationId)
                }
            } else if (message.startsWith('CLEAR_HISTORY:')) {
                console.log("Clear all history request from HTML")
                if (webViewRoot.rootItem) {
                    webViewRoot.rootItem.clearAllHistory()
                }
            } else if (message.startsWith('LOAD_CONVERSATION:')) {
                const conversationId = message.replace('LOAD_CONVERSATION:', '')
                console.log("Load conversation request from HTML:", conversationId)
                if (webViewRoot.rootItem) {
                    webViewRoot.rootItem.loadSpecificConversation(conversationId)
                }
            } else if (message.startsWith('NEW_CHAT:')) {
                console.log("New chat request from HTML")
                if (webViewRoot.rootItem) {
                    webViewRoot.rootItem.clearCurrentConversation()
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
                    (function(){
                        function addNewChatButton(){
                            try{
                                const headerRight = document.querySelector('.header-right');
                                if (!headerRight || document.getElementById('newChatButton')) return;
                                const btn = document.createElement('button');
                                btn.id = 'newChatButton';
                                btn.className = 'history-button';
                                btn.title = 'New Chat';
                                btn.setAttribute('aria-label','New Chat');
                                btn.innerHTML = '<svg class="history-icon" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg" role="img" focusable="false" aria-hidden="true"><path d="M8 1a.75.75 0 0 1 .75.75V7.25h5.5a.75.75 0 0 1 0 1.5h-5.5v5.5a.75.75 0 0 1-1.5 0v-5.5h-5.5a.75.75 0 0 1 0-1.5h5.5V1.75A.75.75 0 0 1 8 1z"/></svg>';
                                btn.addEventListener('click', function(){ console.log('NEW_CHAT:'); });
                                const historyBtn = document.getElementById('historyButton');
                                if (historyBtn && historyBtn.parentNode === headerRight) {
                                    headerRight.insertBefore(btn, historyBtn);
                                } else {
                                    headerRight.insertBefore(btn, headerRight.firstChild);
                                }
                            }catch(e){}
                        }
                        document.addEventListener('keydown', function(ev){
                            if ((ev.ctrlKey || ev.metaKey) && (ev.key === 'n' || ev.key === 'N')) {
                                ev.preventDefault();
                                console.log('NEW_CHAT:');
                            }
                        });
                        if (document.readyState === 'loading') {
                            document.addEventListener('DOMContentLoaded', addNewChatButton);
                        } else {
                            addNewChatButton();
                        }
                    })();
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
            httpCacheType: WebEngineProfile.NoCache
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