import std/strutils

import raylib

import state

const BUTTON_HEIGHT* = 40
const BUTTON_PADDING* = 8

proc mouseInRect*(rect: Rectangle): bool =
    let m = getMousePosition()
    m.x >= rect.x and m.x < rect.x + rect.width and
    m.y >= rect.y and m.y < rect.y + rect.height

proc drawButton*(rect: Rectangle, label: string, active: bool = false): bool =
    let hovered = mouseInRect(rect)
    let bg = if active: Color(r: 100, g: 150, b: 200, a: 255)
             elif hovered: Color(r: 80, g: 80, b: 80, a: 255)
             else: Color(r: 50, g: 50, b: 50, a: 255)
    drawRectangle(rect, bg)
    drawRectangleLines(rect, 1.0, WHITE)
    let fontSize: int32 = 20
    let textWidth = measureText(label, fontSize)
    let tx = rect.x.int32 + (rect.width.int32 - textWidth) div 2
    let ty = rect.y.int32 + (rect.height.int32 - fontSize) div 2
    drawText(label, tx, ty, fontSize, WHITE)
    hovered and isMouseButtonPressed(MouseButton.Left)

proc drawTextField*(rect: Rectangle, field: var TextField, numericOnly: bool = false) =
    # Klick auf Feld aktiviert es, Klick außerhalb deaktiviert
    let hovered = mouseInRect(rect)
    if isMouseButtonPressed(MouseButton.Left):
        field.active = hovered

    let bg = if field.active: Color(r: 40, g: 40, b: 60, a: 255)
             else: Color(r: 30, g: 30, b: 30, a: 255)
    drawRectangle(rect, bg)
    let border = if field.active: Color(r: 150, g: 200, b: 255, a: 255) else: WHITE
    drawRectangleLines(rect, 1.0, border)

    let fontSize: int32 = 20
    let textY = rect.y.int32 + (rect.height.int32 - fontSize) div 2
    drawText(field.value, rect.x.int32 + 6, textY, fontSize, WHITE)

    if field.active:
        # blinkender Caret
        if (getTime() * 2.0).int mod 2 == 0:
            let tw = measureText(field.value, fontSize)
            let caretX = rect.x.int32 + 6 + tw
            drawRectangle(Rectangle(x: caretX.float, y: textY.float, width: 2, height: fontSize.float), WHITE)
        # Input-Zeichen lesen
        var ch = getCharPressed()
        while ch > 0:
            if ch >= 32 and ch <= 125:
                let c = char(ch)
                if numericOnly:
                    if c in {'0'..'9', '-'}:
                        field.value.add(c)
                else:
                    field.value.add(c)
            ch = getCharPressed()
        if isKeyPressed(KeyboardKey.Backspace) and field.value.len > 0:
            field.value.setLen(field.value.len - 1)

proc parseIntOr*(s: string, default: int): int =
    try: parseInt(s.strip()) except CatchableError: default
