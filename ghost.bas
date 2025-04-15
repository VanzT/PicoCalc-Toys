SetPin GP28, AIN
highest = 0.0
lowest = 1.0

Do
    value = Pin(GP28)

    If value < lowest Then
        lowest = value
    End If
    If value > highest Then
        highest = value
    End If

    ' Convert to integers for manual 2-decimal formatting
    iv = Int(value * 100)
    ih = Int(highest * 100)
    il = Int(lowest * 100)

    Print "Now:  "; Int(iv / 100); "."; Right$("0" + Str$(iv Mod 100), 2) + " ";
    Print "High: "; Int(ih / 100); "."; Right$("0" + Str$(ih Mod 100), 2) + " ";
    Print "Low:  "; Int(il / 100); "."; Right$("0" + Str$(il Mod 100), 2)
    Pause 500
    CLS
Loop
