Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
agentDir = fso.GetParentFolderName(WScript.ScriptFullName)
pythonExe = agentDir & "\venv\Scripts\python.exe"
agentPy = agentDir & "\agent.py"

If fso.FileExists(pythonExe) Then
    WshShell.CurrentDirectory = agentDir
    WshShell.Run """" & pythonExe & """ """ & agentPy & """", 0, False
ElseIf fso.FileExists(agentPy) Then
    WshShell.CurrentDirectory = agentDir
    WshShell.Run "py """ & agentPy & """", 0, False
End If
