SetPin gp28,ain
highest = 0.0
lowest = 1.0
Do
  value = Pin(gp28)
  If value >= highest Then
    highest = value
  End If
  If value <= lowest Then
    lowest = value
  End If
  Print lowest
  Pause 0.1
Loop
