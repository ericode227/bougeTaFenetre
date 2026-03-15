#Requires AutoHotkey v2.0
#SingleInstance Force
TraySetIcon(A_ScriptDir "\bougeTaFenetre.ico")

SCRIPT_VERSION := "1.5.0"
INI_FILE := A_ScriptDir "\bougeTaFenetre.ini"

; ================= DESIGN CONSTANTS =================
BG_DARK       := "0D0D15"    ; Fond principal sombre
BG_SURFACE    := "1E1E2E"    ; Fond des sections/cartes
BG_OVERLAY    := "2D2D3D"    ; Fond des boutons
TEXT_PRIMARY  := "CDD6F4"    ; Texte principal (clair)
TEXT_SECONDARY:= "A6ADC8"    ; Texte secondaire (muted)
ACCENT_BLUE   := "89B4FA"    ; Bleu accent (headers, focus)
ACCENT_GREEN  := "A6E3A1"    ; Vert (succès, actif)
ACCENT_YELLOW := "F9E2AF"    ; Jaune (warning)
BORDER_COLOR  := "585B70"    ; Bordures subtiles
BTN_HEIGHT    := 40
BTN_ICON_SIZE := 52
BTN_GAP       := 8
SECTION_GAP   := 16


; ================= STATE =================
global state := Map("STEP", 50, "lastTarget", 0, "fontSize", 11, "guiAOT", true, "rightColVisible", true, "allPreset", 1)
global ctrlGui := 0, miniGui := 0
global lbWindows := 0, lblStep := 0
global windowMap := Map(), favPos := Map()
global aotBar := 0, aotTxt := 0
global lblVolume := 0, lastKnownVol := -1, lastKnownMute := -1
global miniClickCount := 0
global actionButtons := []
global rightColumnControls := []
global col3Controls := []
global editSend := 0
global presetBtns := []
global presetLastClick := Map(1, 0, 2, 0, 3, 0, 4, 0)
global lblPresetIndicator := 0
global miniPresetBtns := []

; ================= INI =================
SaveGuiState(*) {
    global ctrlGui, INI_FILE, state
    if !ctrlGui
        return
    try {
        WinGetPos(&x, &y, , , ctrlGui.Hwnd)
        IniWrite(x,                 INI_FILE, "Gui", "X")
        IniWrite(y,                 INI_FILE, "Gui", "Y")
        IniWrite(state["STEP"],     INI_FILE, "Gui", "STEP")
        IniWrite(state["fontSize"], INI_FILE, "Gui", "Font")
        IniWrite(state["guiAOT"],   INI_FILE, "Gui", "AOT")
    } catch as e {
        MsgBox("Impossible de sauvegarder les préférences :`n" e.Message, "Erreur", "Icon!")
    }
}

LoadGuiState() {
    global INI_FILE, state
    if !FileExist(INI_FILE)
        return ""
    try {
        state["STEP"]     := Integer(IniRead(INI_FILE, "Gui", "STEP", 50))
        state["fontSize"] := Integer(IniRead(INI_FILE, "Gui", "Font", 11))
        state["guiAOT"]   := IniRead(INI_FILE, "Gui", "AOT", 1)
        x := IniRead(INI_FILE, "Gui", "X", "")
        y := IniRead(INI_FILE, "Gui", "Y", "")
        if x = ""
            return ""
        return "x" x " y" y
    } catch {
        return ""
    }
}

; ================= UTIL =================
Snap(val, step) => Round(val / step) * step

SetGuiIcon(hwnd) {
    static hIcon := 0
    if !hIcon
        hIcon := DllCall("LoadImage", "Ptr", 0, "Str", A_ScriptDir "\bougeTaFenetre.ico", "UInt", 1, "Int", 0, "Int", 0, "UInt", 0x10, "Ptr")
    if hIcon {
        SendMessage(0x80, 1, hIcon, , "ahk_id " hwnd)
        SendMessage(0x80, 0, hIcon, , "ahk_id " hwnd)
    }
}

HasValidTarget() {
    global state
    hwnd := state["lastTarget"]
    if !hwnd || !WinExist("ahk_id " hwnd) {
        SoundBeep(300)
        return false
    }
    return true
}

ChangeFont(d) {
    global state, ctrlGui, INI_FILE
    state["fontSize"] := Max(6, Min(24, state["fontSize"] + d))
    try {
        WinGetPos(&x, &y, , , ctrlGui.Hwnd)
        IniWrite(x,                 INI_FILE, "Gui", "X")
        IniWrite(y,                 INI_FILE, "Gui", "Y")
        IniWrite(state["STEP"],     INI_FILE, "Gui", "STEP")
        IniWrite(state["fontSize"], INI_FILE, "Gui", "Font")
        IniWrite(state["guiAOT"],   INI_FILE, "Gui", "AOT")
    } catch as e {
        MsgBox("Erreur sauvegarde police :`n" e.Message, "Erreur", "Icon!")
        return
    }
    Reload()
}

UpdateButtonStates() {
    global actionButtons, state
    hasTarget := state["lastTarget"] && WinExist("ahk_id " state["lastTarget"])
    for btn in actionButtons {
        try btn.Enabled := hasTarget
    }
}

; ================= STEP =================
SliderStepChanged(ctrl, *) {
    global state, lblStep
    state["STEP"] := ctrl.Value
    lblStep.Text := state["STEP"] " px"
    SaveGuiState()
}

ChangeStep(d) {
    global state, lblStep, ctrlGui
    state["STEP"] := Max(1, state["STEP"] + d)
    lblStep.Text := state["STEP"] " px"
    for c in ctrlGui {
        if c.Type = "Slider"
            c.Value := state["STEP"]
    }
    SaveGuiState()
}

; ================= WINDOW ACTIONS =================
MoveTarget(dx, dy) {
    global state
    if !HasValidTarget()
        return
    try {
        hwnd := state["lastTarget"]
        WinGetPos(&x, &y, , , "ahk_id " hwnd)
        WinMove(Snap(x + dx, state["STEP"]), Snap(y + dy, state["STEP"]), , , "ahk_id " hwnd)
    } catch as e {
        MsgBox("Impossible de déplacer la fenêtre :`n" e.Message, "Erreur", "Icon!")
    }
}

ResizeTarget(dw, dh) {
    global state
    if !HasValidTarget()
        return
    try {
        hwnd := state["lastTarget"]
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        WinMove(, , Max(100, w + dw), Max(100, h + dh), "ahk_id " hwnd)
    } catch as e {
        MsgBox("Impossible de redimensionner la fenêtre :`n" e.Message, "Erreur", "Icon!")
    }
}

MaximizeTarget(*) {
    if !HasValidTarget()
        return
    try {
        WinMaximize("ahk_id " state["lastTarget"])
    } catch as e {
        MsgBox("Erreur maximisation :`n" e.Message, "Erreur", "Icon!")
    }
}

RestoreTarget(*) {
    if !HasValidTarget()
        return
    try {
        WinRestore("ahk_id " state["lastTarget"])
    } catch as e {
        MsgBox("Erreur restauration :`n" e.Message, "Erreur", "Icon!")
    }
}

ActivateCurrentTarget(*) {
    if !HasValidTarget()
        return
    try {
        WinActivate("ahk_id " state["lastTarget"])
    } catch as e {
        MsgBox("Erreur activation :`n" e.Message, "Erreur", "Icon!")
    }
}

CenterTarget(*) {
    global state
    if !HasValidTarget()
        return
    try {
        hwnd := state["lastTarget"]
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        MonitorGetWorkArea(, &mx1, &my1, &mx2, &my2)
        WinMove(mx1 + ((mx2 - mx1) - w) // 2, my1 + ((my2 - my1) - h) // 2, , , "ahk_id " hwnd)
    } catch as e {
        MsgBox("Impossible de centrer la fenêtre :`n" e.Message, "Erreur", "Icon!")
    }
}

MoveToNextScreen(*) {
    global state
    if !HasValidTarget()
        return
    try {
        hwnd := state["lastTarget"]
        WinRestore("ahk_id " hwnd)
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        count := MonitorGetCount()
        Loop count {
            MonitorGetWorkArea(A_Index, &mx1, &my1, &mx2, &my2)
            if (x >= mx1 && x < mx2 && y >= my1 && y < my2) {
                next := A_Index + 1
                if next > count
                    next := 1
                MonitorGetWorkArea(next, &nx1, &ny1, &nx2, &ny2)
                WinMove(nx1 + 20, ny1 + 20, w, h, "ahk_id " hwnd)
                break
            }
        }
    } catch as e {
        MsgBox("Impossible de déplacer vers l'écran suivant :`n" e.Message, "Erreur", "Icon!")
    }
}

; ================= VOLUME =================
ChangeVolume(d) {
    try {
        vol := SoundGetVolume()
        SoundSetVolume(Max(0, Min(100, vol + d)))
        UpdateVolumeLabel()
    } catch as e {
        MsgBox("Erreur volume :`n" e.Message, "Erreur", "Icon!")
    }
}

ToggleMute(*) {
    try {
        SoundSetMute(-1)
        UpdateVolumeLabel()
    } catch as e {
        MsgBox("Erreur mute :`n" e.Message, "Erreur", "Icon!")
    }
}

UpdateVolumeLabel() {
    global lblVolume, lastKnownVol, lastKnownMute
    if !lblVolume
        return
    try {
        vol := Round(SoundGetVolume())
        isMuted := SoundGetMute()
        lastKnownVol  := vol
        lastKnownMute := isMuted
        if isMuted
            lblVolume.Text := "🔇 Muet"
        else
            lblVolume.Text := "🔊 " vol "%"
    } catch {
        lblVolume.Text := "?"
    }
}

SyncVolumeLabel() {
    global lblVolume, lastKnownVol, lastKnownMute
    if !lblVolume
        return
    try {
        vol     := Round(SoundGetVolume())
        isMuted := SoundGetMute()
        if vol != lastKnownVol || isMuted != lastKnownMute
            UpdateVolumeLabel()
    } catch {
    }
}

; ================= SEND TO TARGET =================
SendTextToTarget(*) {
    global state, editSend
    if !HasValidTarget()
        return
    text := editSend.Value
    if text = ""
        return
    WinActivate("ahk_id " state["lastTarget"])
    WinWaitActive("ahk_id " state["lastTarget"], , 1)
    SendText(text)
}

SendKeyToTarget(key) {
    global state
    if !HasValidTarget()
        return
    WinActivate("ahk_id " state["lastTarget"])
    WinWaitActive("ahk_id " state["lastTarget"], , 1)
    Send(key)
}

DblClickTargetCenter(*) {
    global state
    if !HasValidTarget()
        return
    try {
        hwnd := state["lastTarget"]
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
        centerX := wx + ww // 2
        centerY := wy + wh // 2
        CoordMode("Mouse", "Screen")
        MouseGetPos(&origX, &origY)
        BlockInput("MouseMove")
        try {
            MouseMove(centerX, centerY)
            Sleep(150)
            Click()
            Sleep(50)
            Click()
            MouseMove(origX, origY)
        } finally {
            BlockInput("MouseMoveOff")
        }
    } catch as e {
        BlockInput("MouseMoveOff")
        MsgBox("Erreur double clic :`n" e.Message, "Erreur", "Icon!")
    }
}

; ================= FAVORITES =================
GetFavKey(hwnd) {
    try {
        title := WinGetTitle("ahk_id " hwnd)
        return RegExReplace(Trim(title), "[=\[\];\r\n]", "_")
    } catch {
        return ""
    }
}

SaveFavorite(*) {
    global state, favPos, INI_FILE
    if !HasValidTarget()
        return
    try {
        hwnd := state["lastTarget"]
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        key := GetFavKey(hwnd)
        if key = ""
            return
        favPos[key] := [x, y, w, h]
        IniWrite(x "," y "," w "," h, INI_FILE, "Favorites", key)
        SoundBeep(900)
        ToolTip("✅ Position sauvegardée")
        SetTimer(() => ToolTip(), -1500)
    } catch as e {
        MsgBox("Erreur sauvegarde favori :`n" e.Message, "Erreur", "Icon!")
    }
}

LoadFavorite(*) {
    global state, favPos, INI_FILE
    if !HasValidTarget()
        return
    hwnd := state["lastTarget"]
    key := GetFavKey(hwnd)
    if key = "" {
        SoundBeep(300)
        return
    }
    if !favPos.Has(key) {
        try {
            val := IniRead(INI_FILE, "Favorites", key, "")
            if val = "" {
                SoundBeep(300)
                ToolTip("⚠️ Aucun favori pour cette fenêtre")
                SetTimer(() => ToolTip(), -1500)
                return
            }
            parts := StrSplit(val, ",")
            favPos[key] := [Integer(parts[1]), Integer(parts[2]), Integer(parts[3]), Integer(parts[4])]
        } catch {
            SoundBeep(300)
            ToolTip("⚠️ Aucun favori pour cette fenêtre")
            SetTimer(() => ToolTip(), -1500)
            return
        }
    }
    try {
        p := favPos[key]
        WinMove(p[1], p[2], p[3], p[4], "ahk_id " hwnd)
        SoundBeep(700)
        ToolTip("✅ Position restaurée")
        SetTimer(() => ToolTip(), -1500)
    } catch as e {
        MsgBox("Erreur restauration favori :`n" e.Message, "Erreur", "Icon!")
    }
}

LvToggleCheck(lv, rowNum) {
    if rowNum = 0
        return
    MouseGetPos(&mx)
    lv.GetPos(&cx)
    checkW := DllCall("GetSystemMetrics", "Int", 49) + 4  ; SM_CXSMICON + marge
    if (mx - cx) < checkW   ; zone checkbox native — laisser Windows gérer
        return
    isChecked := lv.GetNext(rowNum - 1, "Checked") = rowNum
    lv.Modify(rowNum, isChecked ? "-Check" : "Check")
}

LvSetAllChecked(lv, checked) {
    mark := checked ? "Check" : "-Check"
    Loop lv.GetCount()
        lv.Modify(A_Index, mark)
}

SaveSelResult(lv, result, gui) {
    row := lv.GetNext(0, "Checked")
    while row > 0 {
        result["indices"].Push(row)
        row := lv.GetNext(row, "Checked")
    }
    result["confirmed"] := true
    result["done"] := true
    gui.Destroy()
}

DoneSelGui(result, gui) {
    result["done"] := true
    try gui.Destroy()
}

SelFontResize(lv, selResult, selGui, windows, preset, delta) {
    global state
    selResult["_states"] := LvGetStates(lv)
    state["fontSize"] := Max(6, Min(24, state["fontSize"] + delta))
    selResult["resizing"] := true
    selResult["done"] := true
    selGui.Destroy()
}

LvGetStates(lv) {
    states := []
    Loop lv.GetCount()
        states.Push(lv.GetNext(A_Index - 1, "Checked") = A_Index)
    return states
}

ShowSelGui(windows, preset, selResult) {
    global state, BG_DARK, BG_SURFACE, BG_OVERLAY, TEXT_PRIMARY, ACCENT_GREEN, ACCENT_YELLOW
    fontSize := state["fontSize"]

    scale := fontSize / 11.0
    lvW   := Round(520 * scale)
    lvH   := Round(360 * scale)
    btnH  := Round(28 * scale)

    selGui := Gui("+AlwaysOnTop +Resize", "Preset " preset " — Sélectionner les fenêtres")
    selGui.BackColor := BG_DARK
    selGui.SetFont("s" fontSize " c" TEXT_PRIMARY, "Segoe UI")

    selGui.AddText("xm w" lvW " Center", "Sélectionnez les fenêtres à enregistrer")
    lv := selGui.AddListView("xm w" lvW " h" lvH " Checked Background" BG_SURFACE " NoSortHdr -Hdr", ["Fenêtre"])
    lv.ModifyCol(1, lvW - 30)
    hIL := IL_Create(windows.Length)
    lv.SetImageList(hIL)

    savedStates := selResult.Has("_states") ? selResult.Delete("_states") : []
    for i, win in windows {
        checked := (savedStates.Length = 0 || savedStates[i]) ? "Check" : ""
        iconIdx := 0
        try {
            exePath := WinGetProcessPath("ahk_id " win.hwnd)
            iconIdx := IL_Add(hIL, exePath, 1)
        }
        rowOpts := checked . (iconIdx ? " Icon" iconIdx : "")
        lv.Add(rowOpts, win.title)
    }

    bw1 := 50, bw2 := 50, bw3 := Round(110*scale), bw4 := Round(120*scale), bw5 := Round(80*scale), bw6 := Round(80*scale)
    totalBtnW := bw1 + 4 + bw2 + 10 + bw3 + 6 + bw4 + 6 + bw5 + 6 + bw6
    btnX := 8 + Max(0, (lvW - totalBtnW) // 2)

    btnMinus  := selGui.AddButton("x" btnX " y+4 w" bw1 " h" btnH " Background" BG_OVERLAY, "A-")
    btnPlus   := selGui.AddButton("x+4 w" bw2 " h" btnH " Background" BG_OVERLAY, "A+")
    btnAll    := selGui.AddButton("x+10 w" bw3 " h" btnH " Background" BG_OVERLAY, "Tout cocher")
    btnNone   := selGui.AddButton("x+6 w" bw4 " h" btnH " Background" BG_OVERLAY, "Tout décocher")
    btnOK     := selGui.AddButton("x+6 w" bw5 " h" btnH " Background" BG_OVERLAY, "OK")
    btnCancel := selGui.AddButton("x+6 w" bw6 " h" btnH " Background" BG_OVERLAY, "Annuler")

    btnMinus.SetFont("s" fontSize " Bold c" TEXT_PRIMARY)
    btnPlus.SetFont("s" fontSize " Bold c" TEXT_PRIMARY)
    btnAll.SetFont("s" fontSize " c" TEXT_PRIMARY)
    btnNone.SetFont("s" fontSize " c" TEXT_PRIMARY)
    btnOK.SetFont("s" fontSize " Bold c" ACCENT_GREEN)
    btnCancel.SetFont("s" fontSize " Bold c" ACCENT_YELLOW)

    btnMinus.OnEvent("Click", (*) => SelFontResize(lv, selResult, selGui, windows, preset, -1))
    btnPlus.OnEvent("Click",  (*) => SelFontResize(lv, selResult, selGui, windows, preset, +1))
    lv.OnEvent("Click",       LvToggleCheck)
    btnAll.OnEvent("Click",   (*) => LvSetAllChecked(lv, true))
    btnNone.OnEvent("Click",  (*) => LvSetAllChecked(lv, false))
    btnOK.OnEvent("Click",    (*) => SaveSelResult(lv, selResult, selGui))
    btnCancel.OnEvent("Click", (*) => DoneSelGui(selResult, selGui))
    selGui.OnEvent("Close",   (*) => DoneSelGui(selResult, selGui))

    selGui.Show("AutoSize")
    SetGuiIcon(selGui.Hwnd)
}

SaveAllFavorites(*) {
    global INI_FILE, ctrlGui, miniGui, state
    preset := state["allPreset"]
    section := "AllPreset_" preset

    ; === 1. Collecter les fenêtres visibles ===
    windows := []
    zIdx := 0
    for hwnd in WinGetList() {
        zIdx++
        if WinGetPID("ahk_id " hwnd) = DllCall("GetCurrentProcessId")
            continue
        if !DllCall("IsWindowVisible", "ptr", hwnd)
            continue
        title := ""
        try title := WinGetTitle("ahk_id " hwnd)
        if Trim(title) = ""
            continue
        key := RegExReplace(Trim(title), "[=\[\];\r\n]", "_")
        if key = ""
            continue
        try {
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            windows.Push({hwnd: hwnd, title: title, key: key, x: x, y: y, w: w, h: h, z: zIdx})
        } catch {
            ; fenêtre inaccessible
        }
    }

    if windows.Length = 0 {
        ToolTip("⚠️ Aucune fenêtre trouvée")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    ; === 2. Désactiver AlwaysOnTop pour afficher les dialogues ===
    try WinSetAlwaysOnTop(0, "ahk_id " ctrlGui.Hwnd)
    try WinSetAlwaysOnTop(0, "ahk_id " miniGui.Hwnd)

    ; === 3. Confirmation si preset existe déjà ===
    if FileExist(INI_FILE) && InStr(FileRead(INI_FILE), "[" section "]") {
        result := MsgBox("Le preset " preset " existe déjà.`nÉcraser ?", "Confirmer", "YesNo Icon?")
        if result = "No" {
            try WinSetAlwaysOnTop(state["guiAOT"] ? 1 : 0, "ahk_id " ctrlGui.Hwnd)
            try WinSetAlwaysOnTop(1, "ahk_id " miniGui.Hwnd)
            return
        }
    }

    ; === 4. GUI de sélection des fenêtres ===
    selResult := Map("confirmed", false, "done", false, "indices", [])
    loop {
        ShowSelGui(windows, preset, selResult)
        while !selResult["done"]
            Sleep(50)
        if !selResult.Has("resizing")
            break
        selResult["done"] := false
        selResult.Delete("resizing")
    }

    ; Restaurer AlwaysOnTop
    try WinSetAlwaysOnTop(state["guiAOT"] ? 1 : 0, "ahk_id " ctrlGui.Hwnd)
    try WinSetAlwaysOnTop(1, "ahk_id " miniGui.Hwnd)

    if !selResult["confirmed"]
        return
    if selResult["indices"].Length = 0 {
        ToolTip("⚠️ Aucune fenêtre sélectionnée")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    ; === 5. Sauvegarder uniquement les fenêtres cochées ===
    try IniDelete(INI_FILE, section)   ; effacer l'ancien preset avant d'écrire
    count := 0
    for idx in selResult["indices"] {
        win := windows[idx]
        IniWrite(win.x "," win.y "," win.w "," win.h "," win.z, INI_FILE, section, win.key)
        count++
    }

    SoundBeep(900)
    ToolTip("✅ Preset " preset " — " count " fenêtres sauvegardées")
    SetTimer(() => ToolTip(), -2000)
}

RestoreAllFavorites(*) {
    global INI_FILE, state
    preset := state["allPreset"]
    section := "AllPreset_" preset
    count := 0
    notFound := 0
    zOrder := []
    try {
        sectionData := IniRead(INI_FILE, section)
    } catch {
        ToolTip("⚠️ Preset " preset " vide ou introuvable")
        SetTimer(() => ToolTip(), -2000)
        return
    }
    for line in StrSplit(sectionData, "`n", "`r") {
        eqPos := InStr(line, "=")
        if !eqPos
            continue
        key := Trim(SubStr(line, 1, eqPos - 1))
        val := Trim(SubStr(line, eqPos + 1))
        if val = ""
            continue
        parts := StrSplit(val, ",")
        if parts.Length < 4
            continue
        x := Integer(parts[1])
        y := Integer(parts[2])
        w := Integer(parts[3])
        h := Integer(parts[4])
        z := (parts.Length >= 5) ? Integer(parts[5]) : 9999
        found := false
        for hwnd in WinGetList() {
            try {
                title := WinGetTitle("ahk_id " hwnd)
                winKey := RegExReplace(Trim(title), "[=\[\];\r\n]", "_")
                if winKey = key {
                    WinMove(x, y, w, h, "ahk_id " hwnd)
                    zOrder.Push({z: z, hwnd: hwnd})
                    count++
                    found := true
                    break
                }
            } catch {
                ; fenêtre inaccessible
            }
        }
        if !found
            notFound++
    }
    ; Restaurer le Z-order : tri ascendant par z (z=1 = plus haut), puis HWND_INSERTAFTER
    Loop zOrder.Length - 1 {
        i := A_Index
        Loop zOrder.Length - i {
            j := A_Index
            if zOrder[j].z > zOrder[j+1].z {
                temp := zOrder[j]
                zOrder[j] := zOrder[j+1]
                zOrder[j+1] := temp
            }
        }
    }
    ; SWP flags : SWP_NOSIZE(0x1)|SWP_NOMOVE(0x2)|SWP_NOACTIVATE(0x10) = 0x13
    ; D'abord, monter toutes les fenêtres du preset au-dessus des fenêtres non concernées
    ; Trick TOPMOST(-1) → NOTOPMOST(-2) : force le passage au-dessus de tous les non-topmost
    for entry in zOrder {
        try DllCall("SetWindowPos", "Ptr", entry.hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
        try DllCall("SetWindowPos", "Ptr", entry.hwnd, "Ptr", -2, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
    }
    ; Puis restaurer l'ordre relatif entre elles
    if zOrder.Length >= 1
        try DllCall("SetWindowPos", "Ptr", zOrder[1].hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
    Loop zOrder.Length - 1 {
        idx := A_Index + 1
        try DllCall("SetWindowPos", "Ptr", zOrder[idx].hwnd, "Ptr", zOrder[idx-1].hwnd, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
    }
    SoundBeep(700)
    msg := "✅ Preset " preset " — " count " fenêtres replacées"
    if notFound > 0
        msg .= " (" notFound " introuvables)"
    ToolTip(msg)
    SetTimer(() => ToolTip(), -2500)
}

HandlePresetClick(n) {
    global presetLastClick
    now := A_TickCount
    if (now - presetLastClick[n]) < 400 {
        presetLastClick[n] := 0
        SelectAllPreset(n)
        RestoreAllFavorites()
    } else {
        presetLastClick[n] := now
        SelectAllPreset(n)
    }
}

HandleMiniPresetClick(n) {
    SelectAllPreset(n)
    RestoreAllFavorites()
}

HandleMiniPresetSave(n) {
    SelectAllPreset(n)
    SaveAllFavorites()
}

SelectAllPreset(n) {
    global state, lblPresetIndicator, miniPresetBtns, ACCENT_BLUE
    state["allPreset"] := n
    if lblPresetIndicator
        lblPresetIndicator.Text := "Preset actif : " n
    for i, pb in miniPresetBtns
        try pb.Text := (i = n) ? "●" i : i
}

; ================= AOT TARGET =================
ToggleTargetAOT(*) {
    global state, ctrlGui
    if !HasValidTarget()
        return
    try {
        hwnd := state["lastTarget"]
        WinSetAlwaysOnTop(-1, "ahk_id " hwnd)
        Sleep(50)
        UpdateAOTButton()
        RefreshWindowList()
        if state["guiAOT"]
            WinSetAlwaysOnTop(1, "ahk_id " ctrlGui.Hwnd)
    } catch as e {
        MsgBox("Erreur TV :`n" e.Message, "Erreur", "Icon!")
    }
}

UpdateAOTButton() {
    global state, aotBar, aotTxt, ACCENT_GREEN, BG_OVERLAY, TEXT_PRIMARY
    if !aotBar
        return
    hwnd := state["lastTarget"]
    if !hwnd || !WinExist("ahk_id " hwnd) {
        aotBar.Text := "TV"
        aotBar.Opt("Background" BG_OVERLAY)
        aotBar.SetFont("s" (state["fontSize"] - 2) " Bold c" TEXT_PRIMARY)
        return
    }
    try {
        isAOT := WinGetExStyle("ahk_id " hwnd) & 0x8
        if isAOT {
            aotBar.Text := "ON"
            aotBar.Opt("Background" ACCENT_GREEN)
            aotBar.SetFont("s" (state["fontSize"] - 2) " Bold c0D0D15")  ; Texte sombre sur fond vert
        } else {
            aotBar.Text := "OFF"
            aotBar.Opt("Background" BG_OVERLAY)
            aotBar.SetFont("s" (state["fontSize"] - 2) " Bold c" TEXT_PRIMARY)
        }
    } catch {
        aotBar.Text := "TV"
        aotBar.Opt("Background" BG_OVERLAY)
        aotBar.SetFont("s" (state["fontSize"] - 2) " Bold c" TEXT_PRIMARY)
    }
}

; ================= GUI AOT =================
SetGuiAOT(val) {
    global state, ctrlGui
    state["guiAOT"] := val
    WinSetAlwaysOnTop(val, "ahk_id " ctrlGui.Hwnd)
    SaveGuiState()
}

; ================= RIGHT COLUMN TOGGLE =================
ToggleRightColumn(*) {
    global state, ctrlGui, rightColumnControls, col3Controls, btnToggleCol
    state["rightColVisible"] := !state["rightColVisible"]

    for ctrl in rightColumnControls {
        try ctrl.Visible := state["rightColVisible"]
    }
    for ctrl in col3Controls {
        try ctrl.Visible := state["rightColVisible"]
    }

    try {
        scale := state["fontSize"] / 11.0
        fullWidth := Round(1170 * scale)
        halfWidth := Round(520 * scale)

        WinGetPos(&x, &y, , &h, ctrlGui.Hwnd)
        if state["rightColVisible"] {
            WinMove(x, y, fullWidth, h, ctrlGui.Hwnd)
            btnToggleCol.Text := "◄◄ Cacher colonnes →"
        } else {
            WinMove(x, y, halfWidth, h, ctrlGui.Hwnd)
            btnToggleCol.Text := "→ Montrer colonnes ►► "
        }
    }
}

; ================= WINDOW LIST =================
RefreshWindowList(*) {
    global lbWindows, windowMap, ctrlGui, state
    prevHwnd := state["lastTarget"]
    lbWindows.Delete()
    windowMap.Clear()
    hIL := IL_Create(20)
    lbWindows.SetImageList(hIL)
    i := 0
    for hwnd in WinGetList() {
        if ctrlGui && hwnd = ctrlGui.Hwnd
            continue
        if !DllCall("IsWindowVisible", "ptr", hwnd)
            continue
        exStyle := WinGetExStyle("ahk_id " hwnd)
        if (exStyle & 0x8000000)                          ; WS_EX_NOACTIVATE
            continue
        if (exStyle & 0x80) && !(exStyle & 0x40000)       ; WS_EX_TOOLWINDOW sans WS_EX_APPWINDOW
            continue
        title := WinGetTitle("ahk_id " hwnd)
        if Trim(title) = ""
            continue
        i++
        prefix := (exStyle & 0x8) ? "📌 " : ""
        iconIdx := 0
        try {
            exePath := WinGetProcessPath("ahk_id " hwnd)
            iconIdx := IL_Add(hIL, exePath, 1)
        }
        rowOpts := iconIdx ? "Icon" iconIdx : ""
        lbWindows.Add(rowOpts, prefix . title)
        windowMap[i] := hwnd
        if hwnd = prevHwnd
            lbWindows.Modify(i, "Select Focus Vis")
    }
    if prevHwnd && !WinExist("ahk_id " prevHwnd) {
        state["lastTarget"] := 0
        UpdateAOTButton()
        UpdateButtonStates()
    }
}

SelectWindowFromList(lv, rowNum, selected, *) {
    global windowMap, state
    if !selected
        return
    idx := rowNum
    if !windowMap.Has(idx)
        return
    hwnd := windowMap[idx]
    if !WinExist("ahk_id " hwnd) {
        RefreshWindowList()
        return
    }
    state["lastTarget"] := hwnd
    UpdateAOTButton()
    UpdateButtonStates()
}

TrackActiveWindow() {
    global ctrlGui, state, windowMap, lbWindows
    try {
        hwnd := WinGetID("A")
        if WinGetPID("ahk_id " hwnd) = DllCall("GetCurrentProcessId")
            return
        if hwnd = state["lastTarget"]
            return
        state["lastTarget"] := hwnd
        found := false
        for i, id in windowMap {
            if id = hwnd {
                lbWindows.Modify(i, "Select Focus Vis")
                found := true
                break
            }
        }
        if !found {
            RefreshWindowList()
        }
        UpdateAOTButton()
        UpdateButtonStates()
    } catch {
        ; Fenêtre active momentanément inaccessible, on ignore silencieusement
    }
}

; ================= MINI GUI =================
MinimizeToButton(*) {
    global ctrlGui, miniGui, miniPresetBtns, BG_DARK, BG_OVERLAY, TEXT_PRIMARY, state
    ctrlGui.Hide()
    miniGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    miniGui.BackColor := BG_DARK
    miniGui.MarginX := 0
    miniGui.MarginY := 0
    pic := miniGui.AddPicture("x0 y0 w44 h44", A_ScriptDir "\bougeTaFenetre.ico")
    pic.OnEvent("Click",       (*) => HandleMiniClick())
    pic.OnEvent("DoubleClick", (*) => HandleMiniClick())
    pic.OnEvent("ContextMenu", (*) => DragMiniGui())
    btnScr := miniGui.AddButton("x48 y0 w44 h44 Background" BG_OVERLAY, "▶⊡")
    btnScr.SetFont("s11 c" TEXT_PRIMARY)
    btnScr.OnEvent("Click", (*) => MoveToNextScreen())
    btnScr.OnEvent("ContextMenu", (*) => ToggleMiniPresets())
    miniPresetBtns := []
    Loop 4 {
        n := A_Index
        pb := miniGui.AddButton("x" (96 + (n-1)*34) " y0 w30 h44 Background" BG_OVERLAY, n)
        pb.SetFont("s12 c" TEXT_PRIMARY)
        pb.OnEvent("Click",       ((idx) => (*) => HandleMiniPresetClick(idx))(n))
        pb.OnEvent("ContextMenu", ((idx) => (*) => HandleMiniPresetSave(idx))(n))
        pb.Visible := false
        miniPresetBtns.Push(pb)
    }
    miniGui.Show("w92 h44 x10 y10 NoActivate")
    SetGuiIcon(miniGui.Hwnd)
}

DragMiniGui(*) {
    global miniGui
    PostMessage(0xA1, 2, 0, , "ahk_id " miniGui.Hwnd)
}

ToggleMiniPresets() {
    global miniGui, miniPresetBtns, state
    if !miniGui || !miniPresetBtns.Length
        return
    WinGetPos(&gx, &gy, , , miniGui.Hwnd)
    newVisible := !miniPresetBtns[1].Visible
    for i, pb in miniPresetBtns {
        pb.Text := (i = state["allPreset"]) ? "●" i : i
        pb.Visible := newVisible
    }
    if newVisible
        miniGui.Show("x" gx " y" gy " w228 h44 NoActivate")
    else
        miniGui.Show("x" gx " y" gy " w92 h44 NoActivate")
}

HandleMiniClick() {
    global miniClickCount
    miniClickCount++
    if miniClickCount = 1
        SetTimer(ProcessMiniClick, -300)
}

ProcessMiniClick() {
    global miniClickCount
    clicks := miniClickCount
    miniClickCount := 0
    if clicks >= 2
        SnapMiniGuiToNextCorner()
    else
        RestoreFromButton()
}

SnapMiniGuiToNextCorner() {
    global miniGui
    if !miniGui
        return
    WinGetPos(&x, &y, &w, &h, miniGui.Hwnd)
    MonitorGetWorkArea(, &mx1, &my1, &mx2, &my2)
    margin := 10
    isRight  := (x > (mx1 + mx2) / 2)
    isBottom := (y > (my1 + my2) / 2)
    if !isRight && !isBottom
        WinMove(mx2 - w - margin, my1 + margin,     , , miniGui.Hwnd)  ; HG → HD
    else if isRight && !isBottom
        WinMove(mx2 - w - margin, my2 - h - margin, , , miniGui.Hwnd)  ; HD → BD
    else if isRight && isBottom
        WinMove(mx1 + margin,     my2 - h - margin, , , miniGui.Hwnd)  ; BD → BG
    else
        WinMove(mx1 + margin,     my1 + margin,     , , miniGui.Hwnd)  ; BG → HG
}

RestoreFromButton(*) {
    global ctrlGui, miniGui, miniPresetBtns
    miniGui.Destroy()
    miniPresetBtns := []
    ctrlGui.Show()
}

; ================= HELP =================
ShowHelp(fontSize := 0, *) {
    global BG_DARK, BG_OVERLAY, TEXT_PRIMARY, ACCENT_BLUE, state
    if fontSize = 0
        fontSize := state["fontSize"]
    helpGui := Gui("+AlwaysOnTop", "Aide - Bouge ta fenêtre v" SCRIPT_VERSION)
    helpGui.SetFont("s" fontSize " c" TEXT_PRIMARY, "Segoe UI")
    helpGui.BackColor := BG_DARK
    helpGui.MarginX := 15
    helpGui.MarginY := 10

    totalW := 1280
    colW   := 405
    col2X  := 15 + colW + 10   ; 430
    col3X  := col2X + colW + 10 ; 845
    lh     := Round(fontSize * 1.65)   ; hauteur estimée d'une ligne

    helpGui.SetFont("Bold c" ACCENT_BLUE)
    helpGui.AddPicture("xm w96 h96", A_ScriptDir "\bougeTaFenetre.ico")
    helpGui.AddText("x+12 yp+" Round((96 - fontSize * 1.5) / 2) " w" (totalW-112), "📖 GUIDE D'UTILISATION")
    helpGui.SetFont("Norm c" TEXT_PRIMARY)
    helpGui.AddText("xm w" totalW, "")

    ; ── COLONNE 1 : LISTE + RACCOURCIS (auto-position) ───────────────
    helpGui.SetFont("Bold c" ACCENT_BLUE)
    c1 := helpGui.AddText("xm w" colW, "🖱️ LISTE DES FENÊTRES :")
    c1.GetPos(, &yStart)
    yStart := (yStart > 0) ? yStart : (10 + fontSize * 3)
    helpGui.SetFont("Norm c" TEXT_PRIMARY)
    lLeft := helpGui.AddText("xm+10 w" (colW-10), "• Clic simple → Sélectionner une fenêtre`n• Double-clic → Activer la fenêtre`n• Suivi automatique de la fenêtre active`n• Icône de l'application affichée`n• 📌 = fenêtre toujours visible")
    helpGui.AddText("xm w" colW, "")
    helpGui.SetFont("Bold c" ACCENT_BLUE)
    helpGui.AddText("xm w" colW, "⌨️ RACCOURCIS CLAVIER :")
    helpGui.SetFont("Norm c" TEXT_PRIMARY)
    lLast := helpGui.AddText("xm+10 w" (colW-10), "• Alt + Flèches → Déplacer`n• Alt + Maj + Flèches → Redimensionner`n• Alt + C → Centrer`n• Alt + N → Écran suivant`n• Alt + S → Sauver position favorite`n• Alt + R → Restaurer position favorite`n• Alt + T → Basculer Always On Top")
    lLast.GetPos(, &ly, , &lhgt)
    yLeft := (ly > 0) ? ly + lhgt + lh : yStart + lh * 16

    ; ── COLONNE 2 : FONCTIONNALITÉS ──────────────────────────────────
    yR := yStart
    helpGui.SetFont("Bold c" ACCENT_BLUE)
    helpGui.AddText("x" col2X " y" yR " w" colW, "✨ FONCTIONNALITÉS :")
    yR += lh + 4
    helpGui.SetFont("Norm c" TEXT_PRIMARY)
    helpGui.AddText("x" (col2X+10) " y" yR " w" (colW-10),
        "• TV → Toujours visible (vert = actif)`n"
        "• Déplacement → Précision 1–500 px`n"
        "• Favoris → Position individuelle`n"
        "• Presets 1–4 → Toutes les fenêtres`n"
        "   Clic = sélectionner  |  Dbl-clic = replacer`n"
        "   Sauver : sélection de fenêtres + z-order`n"
        "• Volume → ±1% / ±10% ou couper le son`n"
        "• Colonne → Masquer col. droite")
    yR += lh * 8 + 4

    ; ── COLONNE 3 : MINI GUI ─────────────────────────────────────────
    y3 := yStart
    helpGui.SetFont("Bold c" ACCENT_BLUE)
    helpGui.AddText("x" col3X " y" y3 " w" colW, "🖼️ MINI GUI :")
    y3 += lh + 4
    helpGui.SetFont("Norm c" TEXT_PRIMARY)
    helpGui.AddText("x" (col3X+10) " y" y3 " w" (colW-10),
        "• Image app : Clic → Restaurer`n"
        "• Image app : Double-clic → Coin suivant`n"
        "• Image app : Clic droit → Déplacer`n"
        "• ▶⊡ Clic → Écran suivant`n"
        "• ▶⊡ Clic droit → Presets`n"
        "   Clic = replacer  |  Clic droit = sauver")
    y3 += lh * 6 + 4

    ; ── Bas : sous la colonne la plus haute ──────────────────────────
    yBottom := Max(yLeft, yR, y3) + lh
    helpGui.AddText("xm y" yBottom " w" totalW, "")
    btnMinus := helpGui.AddButton("xm w50 h36 Background" BG_OVERLAY, "A-")
    btnMinus.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnPlus := helpGui.AddButton("x+4 w50 h36 Background" BG_OVERLAY, "A+")
    btnPlus.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    helpBtn := helpGui.AddButton("x+10 w100 h36 Background" BG_OVERLAY, "OK")
    helpBtn.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)

    btnMinus.OnEvent("Click", (*) => (helpGui.Destroy(), ShowHelp(Max(8, fontSize - 1))))
    btnPlus.OnEvent("Click", (*) => (helpGui.Destroy(), ShowHelp(fontSize + 1)))
    helpBtn.OnEvent("Click", (*) => helpGui.Destroy())

    helpGui.Show("AutoSize Center")
    SetGuiIcon(helpGui.Hwnd)
}

; ================= SECTION SEPARATOR =================
AddSeparator(g) {
    global state, BORDER_COLOR
    scale := state["fontSize"] / 11.0
    sepWidth := Round(500 * scale)
    g.AddText("xm y+8 w" sepWidth " h1 Background" BORDER_COLOR)
}

; ================= SECTION CARD =================
AddSectionCard(g, title, width, height) {
    global BG_SURFACE, ACCENT_BLUE, TEXT_PRIMARY, state

    ; Fond de la carte
    g.AddText("xm y+12 w" width " h" height " Background" BG_SURFACE)

    ; Header de section
    g.SetFont("s" state["fontSize"] " Bold c" ACCENT_BLUE)
    g.AddText("xm+8 yp+8 c" ACCENT_BLUE, "▸ " title)
    g.SetFont("s" state["fontSize"] " Norm c" TEXT_PRIMARY)
}

; ================= GUI =================
BuildGui(pos := "") {
    global ctrlGui, lbWindows, lblStep, state
    global aotBar, aotTxt, actionButtons, rightColumnControls, btnToggleCol
    global lblVolume, lblPresetIndicator, presetBtns

    ; Tailles dynamiques basées sur fontSize (base = 11)
    scale := state["fontSize"] / 11.0
    btnIconSize := Round(52 * scale)      ; Boutons flèches
    btnHeight := Round(40 * scale)        ; Hauteur standard
    btnGap := Round(8 * scale)            ; Gap entre boutons
    listHeight := Round(240 * scale)      ; Hauteur de la liste
    listWidth := Round(455 * scale)       ; Largeur de la liste
    refreshWidth := Round(40 * scale)     ; Largeur bouton refresh
    colLeftW  := Round(500 * scale)       ; Largeur colonne gauche
    colRightX := Round(520 * scale)       ; Position X colonne droite
    colRightW := Round(310 * scale)       ; Largeur colonne droite
    col3X     := Round(850 * scale)       ; Position X 3ème colonne
    col3W     := Round(300 * scale)       ; Largeur 3ème colonne
    guiWidth  := Round(1170 * scale)      ; Largeur totale (3 colonnes)

    ctrlGui := Gui("+Resize +Border", "Bouge ta fenêtre  v" SCRIPT_VERSION)
    ctrlGui.SetFont("s" state["fontSize"] " q5 c" TEXT_PRIMARY, "Segoe UI")
    ctrlGui.BackColor := BG_DARK
    ctrlGui.MarginX := Round(10 * scale)
    ctrlGui.MarginY := Round(8 * scale)
    ctrlGui.OnEvent("Close", (*) => ExitApp())
    ctrlGui.OnEvent("Size",  (*) => OnGuiResize())

    if state["guiAOT"]
        WinSetAlwaysOnTop(1, ctrlGui.Hwnd)

    ; ── FENÊTRE CIBLE ────────────────────────────────────────────────
    ctrlGui.SetFont("s" state["fontSize"] " Bold c" ACCENT_BLUE)
    ctrlGui.AddText("xm w" colLeftW, "▸ FENÊTRE CIBLE")
    ctrlGui.SetFont("s" state["fontSize"] " Norm c" TEXT_PRIMARY)
    lbWindows := ctrlGui.AddListView("xm w" listWidth " h" listHeight " Background" BG_SURFACE " -Hdr -Multi NoSortHdr", ["Fenêtre"])
    lbWindows.ModifyCol(1, listWidth - 4)
    lbWindows.ToolTip := "Clic simple = sélectionner`nDouble-clic = activer la fenêtre"
    btnRefresh := ctrlGui.AddButton("x+5 yp w" refreshWidth " h" listHeight " Background" BG_OVERLAY, "🔄")
    btnRefresh.SetFont("s" (state["fontSize"] + 3) " c" TEXT_PRIMARY)
    btnRefresh.ToolTip := "Rafraîchir la liste des fenêtres"
    btnRefresh.OnEvent("Click", (*) => RefreshWindowList())
    lbWindows.OnEvent("ItemSelect", SelectWindowFromList)
    lbWindows.OnEvent("DoubleClick", (*) => ActivateCurrentTarget())

    AddSeparator(ctrlGui)

    ; ── DÉPLACER / AOT ───────────────────────────────────────────────
    ctrlGui.SetFont("s" state["fontSize"] " Bold c" ACCENT_BLUE)
    ctrlGui.AddText("xm", "▸ DÉPLACER  /  TOUJOURS VISIBLE")
    ctrlGui.SetFont("s" state["fontSize"] " Norm c" TEXT_PRIMARY)
    cx   := 195
    moveGap := Round(58 * scale)
    tmp  := ctrlGui.AddText("xm y+" moveGap, "")
    tmp.GetPos(, &yBase)
    size := btnIconSize
    gap  := btnGap

    btnUp    := ctrlGui.AddButton("x" cx            " y" yBase                " w" size " h" size " Background" BG_OVERLAY, "▲")
    btnLeft  := ctrlGui.AddButton("x" (cx-size-gap) " y" (yBase+size+gap)     " w" size " h" size " Background" BG_OVERLAY, "◄")
    btnRight := ctrlGui.AddButton("x" (cx+size+gap) " y" (yBase+size+gap)     " w" size " h" size " Background" BG_OVERLAY, "►")
    btnDown  := ctrlGui.AddButton("x" cx            " y" (yBase+(size+gap)*2) " w" size " h" size " Background" BG_OVERLAY, "▼")
    btnUp.SetFont("s" (state["fontSize"] + 5) " c" TEXT_PRIMARY)
    btnLeft.SetFont("s" (state["fontSize"] + 5) " c" TEXT_PRIMARY)
    btnRight.SetFont("s" (state["fontSize"] + 5) " c" TEXT_PRIMARY)
    btnDown.SetFont("s" (state["fontSize"] + 5) " c" TEXT_PRIMARY)
    btnUp.ToolTip := "Déplacer vers le haut (Alt+↑)"
    btnLeft.ToolTip := "Déplacer vers la gauche (Alt+←)"
    btnRight.ToolTip := "Déplacer vers la droite (Alt+→)"
    btnDown.ToolTip := "Déplacer vers le bas (Alt+↓)"
    btnUp.OnEvent("Click",    (*) => MoveTarget(0, -state["STEP"]))
    btnLeft.OnEvent("Click",  (*) => MoveTarget(-state["STEP"], 0))
    btnRight.OnEvent("Click", (*) => MoveTarget(state["STEP"],  0))
    btnDown.OnEvent("Click",  (*) => MoveTarget(0,  state["STEP"]))

    btnAOT := ctrlGui.AddButton("x" cx " y" (yBase+size+gap) " w" size " h" size " Background" BG_OVERLAY, "TV")
    btnAOT.SetFont("s" (state["fontSize"] - 2) " Bold c" TEXT_PRIMARY)
    btnAOT.ToolTip := "Basculer toujours visible (Alt+T)"
    btnAOT.OnEvent("Click", (*) => ToggleTargetAOT())
    aotBar := btnAOT
    aotTxt := btnAOT

    screenBtnX := cx + 2*(size+gap)
    screenBtnW := Round(160 * scale)
    btnScreen := ctrlGui.AddButton("x" screenBtnX " y" (yBase+size+gap) " w" screenBtnW " h" size " Background" BG_OVERLAY, "→ Écran suivant")
    btnScreen.SetFont("s" (state["fontSize"] - 1) " c" TEXT_PRIMARY)
    btnScreen.ToolTip := "Déplacer vers l'écran suivant (Alt+N)"
    btnScreen.OnEvent("Click", (*) => MoveToNextScreen())
    actionButtons.Push(btnUp, btnLeft, btnRight, btnDown, btnAOT, btnScreen)

    ctrlGui.AddText("xm y" (yBase + (size+gap)*2 + size), "")  ; ancrage bas flèches
    AddSeparator(ctrlGui)

    ; ── REDIMENSIONNER ───────────────────────────────────────────────
    ctrlGui.SetFont("s" state["fontSize"] " Bold c" ACCENT_BLUE)
    ctrlGui.AddText("xm", "▸ REDIMENSIONNER")
    ctrlGui.SetFont("s" state["fontSize"] " Norm c" TEXT_PRIMARY)
    btnWidth := Round(152 * scale)  ; 152px pour fontSize=11
    btnLm := ctrlGui.AddButton("x125 y+8 w" btnWidth " h" btnHeight " Background" BG_OVERLAY,  "Largeur −")
    btnLm.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnLp := ctrlGui.AddButton("x+8 w" btnWidth " h" btnHeight " Background" BG_OVERLAY, "Largeur +")
    btnLp.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnHm := ctrlGui.AddButton("x125 y+8 w" btnWidth " h" btnHeight " Background" BG_OVERLAY, "Hauteur −")
    btnHm.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnHp := ctrlGui.AddButton("x+8 w" btnWidth " h" btnHeight " Background" BG_OVERLAY, "Hauteur +")
    btnHp.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnLm.OnEvent("Click", (*) => ResizeTarget(-state["STEP"], 0))
    btnLp.OnEvent("Click", (*) => ResizeTarget( state["STEP"], 0))
    btnHm.OnEvent("Click", (*) => ResizeTarget(0, -state["STEP"]))
    btnHp.OnEvent("Click", (*) => ResizeTarget(0,  state["STEP"]))
    actionButtons.Push(btnLm, btnLp, btnHm, btnHp)

    btnToggleWidth := Round(312 * scale)  ; 312px pour fontSize=11
    btnToggleCol := ctrlGui.AddButton("x125 y+12 w" btnToggleWidth " h" btnHeight " Background" BG_OVERLAY, "◄◄ Cacher colonne →")
    btnToggleCol.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnToggleCol.OnEvent("Click", (*) => ToggleRightColumn())

    ; ══════════════════════════════════════════════════════════════════
    ; COLONNE DROITE - commence ici
    ; ══════════════════════════════════════════════════════════════════
    rightColumnControls := []

    ; ── PAS DE DÉPLACEMENT ───────────────────────────────────────────
    ctrlGui.SetFont("s" state["fontSize"] " Bold c" ACCENT_BLUE)
    rightColumnControls.Push(ctrlGui.AddText("x" colRightX " y15", "▸ PAS DE DÉPLACEMENT"))
    ctrlGui.SetFont("s" state["fontSize"] " Norm c" TEXT_PRIMARY)
    lblStep := ctrlGui.AddText("x" colRightX " y+4 w" colRightW " Center Border Background" BG_SURFACE, state["STEP"] " px")
    rightColumnControls.Push(lblStep)
    btnSmallSize := Round(30 * scale)  ; 30px pour fontSize=11
    btnStepPlus := ctrlGui.AddButton("x" colRightX " y+4 w" btnSmallSize " h" btnSmallSize " Background" BG_OVERLAY, "+")
    btnStepPlus.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnStepPlus.OnEvent("Click", (*) => ChangeStep(10))
    rightColumnControls.Push(btnStepPlus)
    btnStepMinus := ctrlGui.AddButton("x+3 w" btnSmallSize " h" btnSmallSize " Background" BG_OVERLAY, "–")
    btnStepMinus.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnStepMinus.OnEvent("Click", (*) => ChangeStep(-10))
    rightColumnControls.Push(btnStepMinus)
    sld := ctrlGui.AddSlider("x" colRightX " y+4 w" colRightW " Range1-500 Background" BG_SURFACE, state["STEP"])
    sld.OnEvent("Change", SliderStepChanged)
    rightColumnControls.Push(sld)

    ; ── FENÊTRE ──────────────────────────────────────────────────────
    ctrlGui.SetFont("s" state["fontSize"] " Bold c" ACCENT_BLUE)
    rightColumnControls.Push(ctrlGui.AddText("x" colRightX " y+12", "▸ FENÊTRE CIBLE"))
    ctrlGui.SetFont("s" state["fontSize"] " Norm c" TEXT_PRIMARY)
    btnMax    := ctrlGui.AddButton("x" colRightX " y+4 w" btnWidth " h" btnHeight " Background" BG_OVERLAY,  "Maximiser")
    btnMax.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnRest   := ctrlGui.AddButton("x+6 w" btnWidth " h" btnHeight " Background" BG_OVERLAY, "Restaurer")
    btnRest.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnCenter := ctrlGui.AddButton("x" colRightX " y+4 w" colRightW " h" btnHeight " Background" BG_OVERLAY, "Centrer")
    btnCenter.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnMax.ToolTip := "Maximiser la fenêtre"
    btnRest.ToolTip := "Restaurer la taille normale"
    btnCenter.ToolTip := "Centrer sur l'écran (Alt+C)"
    btnMax.OnEvent("Click",    (*) => MaximizeTarget())
    btnRest.OnEvent("Click",   (*) => RestoreTarget())
    btnCenter.OnEvent("Click", (*) => CenterTarget())
    rightColumnControls.Push(btnMax, btnRest, btnCenter)
    actionButtons.Push(btnMax, btnRest, btnCenter)

    ; ── POSITION FAVORITE ────────────────────────────────────────────
    ctrlGui.SetFont("s" state["fontSize"] " Bold c" ACCENT_BLUE)
    rightColumnControls.Push(ctrlGui.AddText("x" colRightX " y+12", "▸ POSITION FAVORITE"))
    ctrlGui.SetFont("s" state["fontSize"] " Norm c" TEXT_PRIMARY)
    btnSavFav := ctrlGui.AddButton("x" colRightX " y+4 w" btnWidth " h" btnHeight " Background" BG_OVERLAY,  "💾 Sauver")
    btnSavFav.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnLodFav := ctrlGui.AddButton("x+6 w" btnWidth " h" btnHeight " Background" BG_OVERLAY, "📂 Restaurer")
    btnLodFav.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnSavFav.ToolTip := "Sauvegarder la position actuelle (Alt+S)"
    btnLodFav.ToolTip := "Restaurer la position sauvegardée (Alt+R)"
    btnSavFav.OnEvent("Click", (*) => SaveFavorite())
    btnLodFav.OnEvent("Click", (*) => LoadFavorite())
    rightColumnControls.Push(btnSavFav, btnLodFav)
    actionButtons.Push(btnSavFav, btnLodFav)
    ; ── PRESETS TOUTES FENÊTRES ──────────────────────────────────────
    ctrlGui.SetFont("s" state["fontSize"] " Bold c" ACCENT_BLUE)
    rightColumnControls.Push(ctrlGui.AddText("x" colRightX " y+8", "▸ TOUTES LES FENÊTRES"))
    ctrlGui.SetFont("s" state["fontSize"] " Norm c" TEXT_PRIMARY)
    presetBtnW := Round((colRightW - 3*6) / 4)
    presetBtns := []
    Loop 4 {
        n := A_Index
        xPos := (n = 1) ? "x" colRightX " y+4" : "x+6"
        pb := ctrlGui.AddButton(xPos " w" presetBtnW " h" btnHeight " Background" BG_OVERLAY, n)
        pb.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
        pb.OnEvent("Click", ((idx) => (*) => HandlePresetClick(idx))(n))
        presetBtns.Push(pb)
        rightColumnControls.Push(pb)
    }
    lblPresetIndicator := ctrlGui.AddText("x" colRightX " y+4 w" colRightW " Center Background" BG_SURFACE, "Preset actif : " state["allPreset"])
    lblPresetIndicator.SetFont("s" (state["fontSize"] - 1) " Italic c" ACCENT_BLUE)
    rightColumnControls.Push(lblPresetIndicator)
    ctrlGui.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnSavAll := ctrlGui.AddButton("x" colRightX " y+4 w" btnWidth " h" btnHeight " Background" BG_OVERLAY, "💾 Sauver tout")
    btnSavAll.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnSavAll.ToolTip := "Sauvegarder toutes les fenêtres dans le preset actif"
    btnSavAll.OnEvent("Click", (*) => SaveAllFavorites())
    rightColumnControls.Push(btnSavAll)
    btnRestAll := ctrlGui.AddButton("x+6 w" btnWidth " h" btnHeight " Background" BG_OVERLAY, "📂 Replacer tout")
    btnRestAll.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnRestAll.ToolTip := "Replacer toutes les fenêtres depuis le preset actif"
    btnRestAll.OnEvent("Click", (*) => RestoreAllFavorites())
    rightColumnControls.Push(btnRestAll)

    ; ── VOLUME ───────────────────────────────────────────────────────
    ctrlGui.SetFont("s" state["fontSize"] " Bold c" ACCENT_BLUE)
    rightColumnControls.Push(ctrlGui.AddText("x" colRightX " y+12", "▸ VOLUME DE WINDOWS"))
    ctrlGui.SetFont("s" state["fontSize"] " Norm c" TEXT_PRIMARY)
    lblVolume := ctrlGui.AddText("x" colRightX " y+4 w" colRightW " Center Border Background" BG_SURFACE, "🔊 ??%")
    rightColumnControls.Push(lblVolume)
    btnVolMinus := ctrlGui.AddButton("x" colRightX " y+4 w" btnWidth " h" btnHeight " Background" BG_OVERLAY, "Vol −1")
    btnVolMinus.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnVolMinus.OnEvent("Click", (*) => ChangeVolume(-1))
    rightColumnControls.Push(btnVolMinus)
    btnVolPlus := ctrlGui.AddButton("x+6 w" btnWidth " h" btnHeight " Background" BG_OVERLAY, "Vol +1")
    btnVolPlus.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnVolPlus.OnEvent("Click", (*) => ChangeVolume(1))
    rightColumnControls.Push(btnVolPlus)
    btnVolMinus10 := ctrlGui.AddButton("x" colRightX " y+4 w" btnWidth " h" btnHeight " Background" BG_OVERLAY, "Vol −10")
    btnVolMinus10.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnVolMinus10.OnEvent("Click", (*) => ChangeVolume(-10))
    rightColumnControls.Push(btnVolMinus10)
    btnVolPlus10 := ctrlGui.AddButton("x+6 w" btnWidth " h" btnHeight " Background" BG_OVERLAY, "Vol +10")
    btnVolPlus10.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnVolPlus10.OnEvent("Click", (*) => ChangeVolume(10))
    rightColumnControls.Push(btnVolPlus10)
    btnMute := ctrlGui.AddButton("x" colRightX " y+4 w" colRightW " h" btnHeight " Background" BG_OVERLAY, "🔇 Muet / Réactiver")
    btnMute.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnMute.OnEvent("Click", (*) => ToggleMute())
    rightColumnControls.Push(btnMute)

    ; ── INTERFACE ────────────────────────────────────────────────────
    ctrlGui.SetFont("s" state["fontSize"] " Bold c" ACCENT_BLUE)
    rightColumnControls.Push(ctrlGui.AddText("x" colRightX " y+12", "▸ INTERFACE"))
    ctrlGui.SetFont("s" state["fontSize"] " Norm c" TEXT_PRIMARY)
    fontBtnX := colRightX + Max(0, (colRightW - (2 * btnWidth + 6)) // 2)
    btnFontMinus := ctrlGui.AddButton("x" fontBtnX " y+4 w" btnWidth " h" btnHeight " Background" BG_OVERLAY,  "Police −")
    btnFontMinus.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnFontMinus.OnEvent("Click", (*) => ChangeFont(-1))
    rightColumnControls.Push(btnFontMinus)
    btnFontPlus := ctrlGui.AddButton("x+6 w" btnWidth " h" btnHeight " Background" BG_OVERLAY, "Police +")
    btnFontPlus.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnFontPlus.OnEvent("Click", (*) => ChangeFont(1))
    rightColumnControls.Push(btnFontPlus)

    rightColumnControls.Push(ctrlGui.AddText("x" colRightX " y+8", "Fenêtre toujours visible :"))
    radOn  := ctrlGui.AddRadio("x" (colRightX+10) " y+4", "Oui")
    radOff := ctrlGui.AddRadio("x+15",       "Non")
    if state["guiAOT"]
        radOn.Value := 1
    else
        radOff.Value := 1
    radOn.OnEvent("Click",  (*) => SetGuiAOT(1))
    radOff.OnEvent("Click", (*) => SetGuiAOT(0))
    rightColumnControls.Push(radOn, radOff)

    btnSmallWidth := Round(80 * scale)   ; 80px pour fontSize=11
    btnSmallHeight := Round(36 * scale)  ; 36px pour fontSize=11
    row3X := colRightX + Max(0, (colRightW - (3 * btnSmallWidth + 8)) // 2)
    row1X := colRightX + Max(0, (colRightW - btnSmallWidth) // 2)
    btnSave := ctrlGui.AddButton("x" row3X " y+6 w" btnSmallWidth " h" btnSmallHeight " Background" BG_OVERLAY, "💾 Sauver")
    btnSave.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnSave.OnEvent("Click", (*) => SaveGuiState())
    rightColumnControls.Push(btnSave)
    btnReload := ctrlGui.AddButton("x+4 w" btnSmallWidth " h" btnSmallHeight " Background" BG_OVERLAY, "🔁 Recharger")
    btnReload.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnReload.OnEvent("Click",  (*) => Reload())
    rightColumnControls.Push(btnReload)
    btnMinimize := ctrlGui.AddButton("x+4 w" btnSmallWidth " h" btnSmallHeight " Background" BG_OVERLAY, "🪟 Réduire")
    btnMinimize.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnMinimize.OnEvent("Click", (*) => MinimizeToButton())
    rightColumnControls.Push(btnMinimize)
    btnHelp := ctrlGui.AddButton("x" row1X " y+6 w" btnSmallWidth " h" btnSmallHeight " Background" BG_OVERLAY, "📖 Aide")
    btnHelp.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnHelp.OnEvent("Click", (*) => ShowHelp())
    rightColumnControls.Push(btnHelp)

    ; ══════════════════════════════════════════════════════════════════
    ; 3ÈME COLONNE - ENVOYER À LA CIBLE
    ; ══════════════════════════════════════════════════════════════════
    col3Controls := []

    ; ── ENVOYER À LA CIBLE ───────────────────────────────────────────
    ctrlGui.SetFont("s" state["fontSize"] " Bold c" ACCENT_BLUE)
    col3Controls.Push(ctrlGui.AddText("x" col3X " y15", "▸ ENVOYER À LA CIBLE"))
    ctrlGui.SetFont("s" state["fontSize"] " Norm c" TEXT_PRIMARY)

    editSend := ctrlGui.AddEdit("x" col3X " y+4 w" col3W " Background" BG_SURFACE, "")
    editSend.SetFont("s" state["fontSize"] " c" TEXT_PRIMARY)
    editSend.ToolTip := "Texte à envoyer à la fenêtre cible"
    col3Controls.Push(editSend)

    sendBtnW := Round((col3W - btnGap) / 2)
    btnSend := ctrlGui.AddButton("x" col3X " y+4 w" sendBtnW " h" btnHeight " Background" BG_OVERLAY, "▶ Envoyer")
    btnSend.SetFont("s" state["fontSize"] " Bold c" ACCENT_GREEN)
    btnSend.ToolTip := "Envoyer le texte à la fenêtre cible (active la fenêtre)"
    btnSend.OnEvent("Click", SendTextToTarget)
    col3Controls.Push(btnSend)
    actionButtons.Push(btnSend)

    btnClear := ctrlGui.AddButton("x+8 w" sendBtnW " h" btnHeight " Background" BG_OVERLAY, "✕ Effacer")
    btnClear.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnClear.ToolTip := "Vider le champ texte"
    btnClear.OnEvent("Click", (*) => (editSend.Value := ""))
    col3Controls.Push(btnClear)

    ; ── TOUCHES SPÉCIALES ────────────────────────────────────────────
    ctrlGui.SetFont("s" state["fontSize"] " Bold c" ACCENT_BLUE)
    col3Controls.Push(ctrlGui.AddText("x" col3X " y+12", "▸ TOUCHES SPÉCIALES"))
    ctrlGui.SetFont("s" state["fontSize"] " Norm c" TEXT_PRIMARY)

    spBtnW := Round((col3W - 2*btnGap) / 3)

    btnEnter := ctrlGui.AddButton("x" col3X " y+4 w" spBtnW " h" btnHeight " Background" BG_OVERLAY, "Enter")
    btnEnter.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnEnter.OnEvent("Click", (*) => SendKeyToTarget("{Enter}"))
    col3Controls.Push(btnEnter)
    actionButtons.Push(btnEnter)

    btnTab := ctrlGui.AddButton("x+8 w" spBtnW " h" btnHeight " Background" BG_OVERLAY, "Tab")
    btnTab.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnTab.OnEvent("Click", (*) => SendKeyToTarget("{Tab}"))
    col3Controls.Push(btnTab)
    actionButtons.Push(btnTab)

    btnEsc := ctrlGui.AddButton("x+8 w" spBtnW " h" btnHeight " Background" BG_OVERLAY, "Esc")
    btnEsc.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnEsc.OnEvent("Click", (*) => SendKeyToTarget("{Esc}"))
    col3Controls.Push(btnEsc)
    actionButtons.Push(btnEsc)

    btnSpace := ctrlGui.AddButton("x" col3X " y+4 w" spBtnW " h" btnHeight " Background" BG_OVERLAY, "Space")
    btnSpace.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnSpace.OnEvent("Click", (*) => SendKeyToTarget("{Space}"))
    col3Controls.Push(btnSpace)
    actionButtons.Push(btnSpace)

    btnBksp := ctrlGui.AddButton("x+8 w" spBtnW " h" btnHeight " Background" BG_OVERLAY, "Bksp")
    btnBksp.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnBksp.OnEvent("Click", (*) => SendKeyToTarget("{Backspace}"))
    col3Controls.Push(btnBksp)
    actionButtons.Push(btnBksp)

    btnDel := ctrlGui.AddButton("x+8 w" spBtnW " h" btnHeight " Background" BG_OVERLAY, "Del")
    btnDel.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnDel.OnEvent("Click", (*) => SendKeyToTarget("{Delete}"))
    col3Controls.Push(btnDel)
    actionButtons.Push(btnDel)

    ; ── RACCOURCIS CLAVIER ───────────────────────────────────────────
    ctrlGui.SetFont("s" state["fontSize"] " Bold c" ACCENT_BLUE)
    col3Controls.Push(ctrlGui.AddText("x" col3X " y+12", "▸ RACCOURCIS CLAVIER"))
    ctrlGui.SetFont("s" state["fontSize"] " Norm c" TEXT_PRIMARY)

    scBtnW := Round((col3W - 3*btnGap) / 4)

    btnCtrlA := ctrlGui.AddButton("x" col3X " y+4 w" scBtnW " h" btnHeight " Background" BG_OVERLAY, "Ctrl+A")
    btnCtrlA.SetFont("s" (state["fontSize"] - 1) " Bold c" TEXT_PRIMARY)
    btnCtrlA.OnEvent("Click", (*) => SendKeyToTarget("^a"))
    col3Controls.Push(btnCtrlA)
    actionButtons.Push(btnCtrlA)

    btnCtrlC := ctrlGui.AddButton("x+8 w" scBtnW " h" btnHeight " Background" BG_OVERLAY, "Ctrl+C")
    btnCtrlC.SetFont("s" (state["fontSize"] - 1) " Bold c" TEXT_PRIMARY)
    btnCtrlC.OnEvent("Click", (*) => SendKeyToTarget("^c"))
    col3Controls.Push(btnCtrlC)
    actionButtons.Push(btnCtrlC)

    btnCtrlV := ctrlGui.AddButton("x+8 w" scBtnW " h" btnHeight " Background" BG_OVERLAY, "Ctrl+V")
    btnCtrlV.SetFont("s" (state["fontSize"] - 1) " Bold c" TEXT_PRIMARY)
    btnCtrlV.OnEvent("Click", (*) => SendKeyToTarget("^v"))
    col3Controls.Push(btnCtrlV)
    actionButtons.Push(btnCtrlV)

    btnCtrlZ := ctrlGui.AddButton("x+8 w" scBtnW " h" btnHeight " Background" BG_OVERLAY, "Ctrl+Z")
    btnCtrlZ.SetFont("s" (state["fontSize"] - 1) " Bold c" TEXT_PRIMARY)
    btnCtrlZ.OnEvent("Click", (*) => SendKeyToTarget("^z"))
    col3Controls.Push(btnCtrlZ)
    actionButtons.Push(btnCtrlZ)

    ; ── ACTIONS SOURIS ───────────────────────────────────────────────
    ctrlGui.SetFont("s" state["fontSize"] " Bold c" ACCENT_BLUE)
    col3Controls.Push(ctrlGui.AddText("x" col3X " y+12", "▸ ACTIONS SOURIS"))
    ctrlGui.SetFont("s" state["fontSize"] " Norm c" TEXT_PRIMARY)

    btnDblClick := ctrlGui.AddButton("x" col3X " y+4 w" col3W " h" btnHeight " Background" BG_OVERLAY, "🖱️ Double clic au centre")
    btnDblClick.SetFont("s" state["fontSize"] " Bold c" TEXT_PRIMARY)
    btnDblClick.ToolTip := "Double clic au centre de la fenêtre cible, puis remet la souris à sa position initiale"
    btnDblClick.OnEvent("Click", DblClickTargetCenter)
    col3Controls.Push(btnDblClick)
    actionButtons.Push(btnDblClick)

    if pos = ""
        ctrlGui.Show("w" guiWidth " Center")
    else
        ctrlGui.Show("w" guiWidth " " pos)
    SetGuiIcon(ctrlGui.Hwnd)

    RefreshWindowList()
    SetTimer(TrackActiveWindow, 300)
    SetTimer(SyncVolumeLabel, 1000)
    UpdateAOTButton()
    UpdateButtonStates()
    UpdateVolumeLabel()
}

OnGuiResize() {
    ; Réservé pour adaptations futures
}

; ================= HOTKEYS =================
#HotIf state["lastTarget"]
!Up::    MoveTarget(0,  -state["STEP"])
!Down::  MoveTarget(0,   state["STEP"])
!Left::  MoveTarget(-state["STEP"], 0)
!Right:: MoveTarget( state["STEP"], 0)
!+Up::   ResizeTarget(0, -state["STEP"])
!+Down:: ResizeTarget(0,  state["STEP"])
!+Left:: ResizeTarget(-state["STEP"], 0)
!+Right::ResizeTarget( state["STEP"], 0)
!c::     CenterTarget()
!n::     MoveToNextScreen()
!s::     SaveFavorite()
!r::     LoadFavorite()
!t::     ToggleTargetAOT()
#HotIf

pos := LoadGuiState()
BuildGui(pos)