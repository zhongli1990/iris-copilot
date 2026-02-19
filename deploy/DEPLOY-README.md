# Deployment Package — Quick Reference

## Files in This Directory

| File | Purpose |
|------|---------|
| `ImportAll.cls` | ObjectScript class that imports and compiles all 24 AIAgent classes in correct dependency order |
| `deploy-windows.bat` | Windows batch script to copy files and display Terminal commands |
| `DEPLOY-README.md` | This file |

## Fastest Path to Deploy

### Option 1: One-Line Terminal Deploy

Copy the entire `AIAgent/` folder to the IRIS server, then in IRIS Terminal:

```objectscript
// Change to your target namespace first
zn "HSBUS"

// Load the import helper
do $system.OBJ.Load("C:\path\to\AIAgent\deploy\ImportAll.cls", "ck")

// Import + compile + install in one step
do ##class(AIAgent.Deploy.ImportAll).QuickDeploy("C:\path\to\AIAgent\cls\")

// Configure API keys
do ##class(AIAgent.Install.Installer).Configure("http://localhost:3100", "sk-ant-...", "sk-...", "", "")
```

### Option 2: Studio Import

1. Open Studio, connect to your namespace
2. Tools > Import Local > select `deploy/ImportAll.cls` > Open
3. Compile (Ctrl+Shift+F7)
4. Tools > Terminal, then:
   ```objectscript
   do ##class(AIAgent.Deploy.ImportAll).Run("C:\path\to\AIAgent\cls\")
   do ##class(AIAgent.Install.Installer).Run()
   ```

### Option 3: LoadDir (simplest but no progress display)

```objectscript
do $system.OBJ.LoadDir("C:\path\to\AIAgent\cls\", "ck")
do ##class(AIAgent.Install.Installer).Run()
```

## After Deployment

1. Start the Node.js bridge: `cd bridge && npm install && npm start`
2. Open: `http://your-iris-server:52773/ai/AIAgent.UI.Chat.cls`
3. Full instructions: see `docs/DEPLOYMENT-GUIDE.md`
