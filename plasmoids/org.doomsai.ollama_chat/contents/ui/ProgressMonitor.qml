import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: progressMonitor
    
    property var parentRoot: null
    property bool isMonitoring: false
    property string currentStep: ""
    property string currentMessage: ""
    property int currentPercent: 0
    property string currentSpeed: ""
    
    signal progressUpdated(string step, string message, int percent, string speed)
    signal setupCompleted()
    signal setupFailed(string error)
    
    function startSetup(model) {
        console.log("Starting setup with progress monitoring...")
        isMonitoring = true
        
        // Start the setup process
        setupProcess.connectSource("bash '" + parentRoot.pkgFile("../scripts/progress-monitor.sh") + "' '" + model + "'")
        
        // Start monitoring progress
        progressTimer.start()
    }
    
    function stopMonitoring() {
        isMonitoring = false
        progressTimer.stop()
        setupProcess.disconnectSource()
        progressReader.disconnectSource()
    }
    
    // Timer to periodically read progress
    Timer {
        id: progressTimer
        interval: 500
        repeat: true
        running: false
        
        onTriggered: {
            if (isMonitoring) {
                progressReader.connectSource("bash '" + parentRoot.pkgFile("../scripts/progress-reader.sh") + "'")
            }
        }
    }
    
    // Setup process executor
    Plasma5Support.DataSource {
        id: setupProcess
        engine: "executable"
        
        onNewData: function(source, data) {
            const out = data["stdout"] || ""
            const err = data["stderr"] || ""
            const exitCode = data["exit code"]
            
            if (out) {
                console.log("Setup output:", out)
            }
            
            if (err) {
                console.warn("Setup error:", err)
            }
            
            if (exitCode !== undefined) {
                setupProcess.disconnectSource(source)
                
                if (exitCode === 0) {
                    console.log("Setup completed successfully")
                    stopMonitoring()
                    setupCompleted()
                } else {
                    console.error("Setup failed with code:", exitCode)
                    stopMonitoring()
                    setupFailed("Setup failed with exit code: " + exitCode)
                }
            }
        }
    }
    
    // Progress reader
    Plasma5Support.DataSource {
        id: progressReader
        engine: "executable"
        
        onNewData: function(source, data) {
            const out = data["stdout"] || ""
            const exitCode = data["exit code"]
            
            if (exitCode !== undefined) {
                progressReader.disconnectSource(source)
                
                if (out && out.startsWith("PROGRESS:")) {
                    parseProgress(out.trim())
                }
            }
        }
    }
    
    function parseProgress(line) {
        // Parse progress: PROGRESS:step:message:percent:speed (speed is optional)
        const parts = line.split(":")
        if (parts.length >= 4) {
            const step = parts[1]
            let message, percent, speed = ""
            
            if (parts.length >= 5) {
                // Has speed info: PROGRESS:step:message:percent:speed
                message = parts.slice(2, -2).join(":")
                percent = parseInt(parts[parts.length - 2])
                speed = parts[parts.length - 1]
            } else {
                // No speed info: PROGRESS:step:message:percent
                message = parts.slice(2, -1).join(":")
                percent = parseInt(parts[parts.length - 1])
            }
            
            // Update current state
            currentStep = step
            currentMessage = message
            currentPercent = percent
            currentSpeed = speed
            
            // Emit signal
            progressUpdated(step, message, percent, speed)
            
            console.log("Progress update:", step, message, percent, speed)
            
            // Check for completion
            if (step === "complete" && percent >= 100) {
                stopMonitoring()
                setupCompleted()
            }
        }
    }
}