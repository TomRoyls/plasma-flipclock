pragma ComponentBehavior: Bound

/*
 * CaptureDemo.qml — render a deterministic idle → minute flip → idle sequence.
 *
 * Usage:
 *   qml6 -I package/contents/ui tools/CaptureDemo.qml -- /tmp/frames 0 204
 *
 * The output directory must exist.  The individual PNGs are intentionally left
 * to ffmpeg: it has much better palette generation and GIF optimisation than
 * Qt's GIF writer.
 */
import QtQuick
import QtQuick.Window
import "../package/contents/ui"

Window {
    id: win

    readonly property var argv: Qt.application.arguments
    readonly property string outputDir: argv[argv.length - 3]
    readonly property int firstFrame: parseInt(argv[argv.length - 2])
    readonly property int endFrame: parseInt(argv[argv.length - 1])
    readonly property int fps: 60
    readonly property int idleFrames: 3 * fps
    readonly property int flipFrames: Math.ceil(800 / 1000 * fps)
    readonly property int totalFrames: idleFrames + flipFrames + idleFrames

    width: 996
    height: 566
    visible: true
    color: "#5a6472"
    flags: Qt.FramelessWindowHint | Qt.Tool
    title: "flip-clock-demo-capture"

    property int frame: firstFrame
    property bool captureBusy: false

    FlipClock {
        id: clock
        anchors.fill: parent
        animate: false
        hours: "12"
        minutes: "47"
        hasWeather: true
        wxLocation: "London"
        wxCondition: "Mostly Sunny"
        wxTemperature: "23°"
        wxRange: "H: 25°\nL: 18°"
        wxIcon: "weather-few-clouds"
        wxVariationKey: "2026-07-30|London"
    }

    Timer {
        id: settle
        interval: 800
        running: true
        onTriggered: recorder.start()
    }

    Timer {
        id: recorder
        interval: 0
        repeat: false
        onTriggered: win.captureFrame()
    }

    // Qt's OutBounce curve, matching the curve used by FlipCard's two phases.
    function outBounce(t) {
        const n = 7.5625
        const d = 2.75
        if (t < 1 / d)
            return n * t * t
        if (t < 2 / d) {
            t -= 1.5 / d
            return n * t * t + 0.75
        }
        if (t < 2.5 / d) {
            t -= 2.25 / d
            return n * t * t + 0.9375
        }
        t -= 2.625 / d
        return n * t * t + 0.984375
    }

    function setDemoState() {
        const card = clock.minuteCardItem
        const t = frame / fps
        const flipStart = 3.0
        const midpoint = 3.4
        const flipEnd = 3.8

        if (t < flipStart) {
            card.oldDigits = "47"
            card.newDigits = "47"
            card.upperAngle = 0
            card.lowerAngle = 0
            card.flipping = false
        } else if (t < midpoint) {
            card.oldDigits = "47"
            card.newDigits = "48"
            card.upperAngle = -90 * outBounce((t - flipStart) / (midpoint - flipStart))
            card.lowerAngle = 90
            card.flipping = true
        } else if (t < flipEnd) {
            card.oldDigits = "47"
            card.newDigits = "48"
            card.upperAngle = -90
            card.lowerAngle = 90 * (1 - outBounce((t - midpoint) / (flipEnd - midpoint)))
            card.flipping = true
        } else {
            card.oldDigits = "48"
            card.newDigits = "48"
            card.upperAngle = 0
            card.lowerAngle = 0
            card.flipping = false
        }
    }

    function captureFrame() {
        if (captureBusy)
            return

        setDemoState()

        captureBusy = true
        const path = outputDir + "/frame" + String(frame).padStart(3, "0") + ".png"
        const ok = win.contentItem.grabToImage(function(result) {
            if (!result.saveToFile(path)) {
                console.log("ERR save " + path)
                Qt.exit(1)
                return
            }

            ++win.frame
            win.captureBusy = false
            if (win.frame === win.endFrame) {
                console.log("OK " + win.frame + " frames in " + outputDir)
                Qt.exit(0)
            } else {
                // Let the scene graph present this state before requesting the
                // next grab; a repeating zero-interval timer starves it.
                recorder.start()
            }
        }, Qt.size(win.width, win.height))

        if (!ok) {
            console.log("ERR grabToImage refused")
            Qt.exit(2)
        }
    }

    Timer {
        interval: 90000
        running: true
        onTriggered: {
            console.log("ERR timeout")
            Qt.exit(3)
        }
    }
}
