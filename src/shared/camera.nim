import std/math

import raylib

proc updateCameraControls*(camera: var Camera2D, uiHovered: bool) =
    block MOVE_CAMERA:
        let scrollSpeedZoomFactor = 1.0 / camera.zoom
        let cameraSpeed = min(10.0 * scrollSpeedZoomFactor, 70.0)

        if isKeyDown(KeyboardKey.Right) or isKeyDown(KeyboardKey.D): camera.target.x += cameraSpeed
        if isKeyDown(KeyboardKey.Left) or isKeyDown(KeyboardKey.A): camera.target.x -= cameraSpeed
        if isKeyDown(KeyboardKey.Down) or isKeyDown(KeyboardKey.S): camera.target.y += cameraSpeed
        if isKeyDown(KeyboardKey.Up) or isKeyDown(KeyboardKey.W): camera.target.y -= cameraSpeed

        if isMouseButtonDown(MouseButton.Middle):
            let mouseDelta = getMouseDelta()
            camera.target.x -= mouseDelta.x * scrollSpeedZoomFactor
            camera.target.y -= mouseDelta.y * scrollSpeedZoomFactor

    block ZOOM_CAMERA:
        if uiHovered: return
        let zoomSpeed = 0.1
        if isKeyDown(KeyboardKey.Equal): camera.zoom += zoomSpeed
        if isKeyDown(KeyboardKey.Minus): camera.zoom -= zoomSpeed
        camera.zoom += getMouseWheelMove() * zoomSpeed
        camera.zoom = clamp(camera.zoom, 0.1, 5.0)
