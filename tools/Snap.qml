pragma ComponentBehavior: Bound

/*
 * Snap.qml — render a component at an exact size and write a PNG, then exit.
 *
 *   QT_QPA_PLATFORM=offscreen QT_SCALE_FACTOR=1 \
 *     qml6 -I package/contents/ui tools/Snap.qml -- FlipClock.qml 996 566 out.png
 *
 * Exit codes: 0 ok, 1 save failed, 2 load failed, 3 grab refused, 4 timeout.
 *
 * Note: never fall back to the software backend. It implements no ShaderEffect
 * or ShaderEffectSource, so every gradient-masked digit and every glow would
 * come out blank -- i.e. it would silently invalidate exactly what we diff.
 */
import QtQuick
import QtQuick.Window

Window {
    id: win

    readonly property var argv: Qt.application.arguments
    readonly property string src: argv[argv.length - 4]
    readonly property int pw: parseInt(argv[argv.length - 3])
    readonly property int ph: parseInt(argv[argv.length - 2])
    readonly property string outPath: argv[argv.length - 1]

    width: pw
    height: ph
    visible: true                  // an unexposed window never renders
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.Tool
    title: "snap"

    property int frames: 0

    Loader {
        id: loader
        anchors.fill: parent
        asynchronous: false
        source: win.src

        onStatusChanged: {
            if (status === Loader.Error) {
                console.log("ERR load " + win.src)
                exiter.code = 2
                exiter.start()
            }
        }
        onLoaded: {
            // Freeze anything time-driven so grabs are deterministic.
            if (item && item.animate !== undefined)
                item.animate = false
        }
    }

    // grabToImage needs a live scene graph, and every ShaderEffectSource and
    // cached glow has to have been filled at least once. A static scene renders
    // once and then stops, so counting frameSwapped would stall -- just give it
    // a beat after load instead.
    Timer {
        id: settle
        interval: 500
        running: loader.status === Loader.Ready
        onTriggered: win.snap()
    }

    function snap() {
        const ok = loader.grabToImage(function (result) {
            const saved = result.saveToFile(win.outPath)
            console.log(saved ? ("OK " + win.outPath) : ("ERR save " + win.outPath))
            exiter.code = saved ? 0 : 1
            exiter.start()          // never call Qt.exit() inside the grab callback
        }, Qt.size(win.pw, win.ph))

        if (!ok) {
            console.log("ERR grabToImage refused")
            exiter.code = 3
            exiter.start()
        }
    }

    Timer {
        id: exiter
        property int code: 0
        interval: 0
        onTriggered: Qt.exit(code)
    }

    Timer {
        interval: 10000
        running: true
        onTriggered: {
            console.log("ERR timeout")
            Qt.exit(4)
        }
    }
}
