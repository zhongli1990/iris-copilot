/// Deployment helper: imports and compiles all AIAgent classes in the correct dependency order.
/// 
/// Usage from IRIS Terminal:
///   do $system.OBJ.Load("C:\path\to\deploy\ImportAll.cls", "ck")
///   do ##class(AIAgent.Deploy.ImportAll).Run("C:\path\to\cls\")
/// 
/// Usage from Studio:
///   Import this file first, then open Terminal and run the commands above.
/// 
/// Part of the IRIS AI Agent Platform (IRIS Copilot).
Class AIAgent.Deploy.ImportAll Extends %RegisteredObject
{

/// Import and compile all 24 AIAgent classes from the specified directory.
/// <p>The directory should contain the AIAgent/ subdirectory with all .cls files.</p>
/// <p>Example: do ##class(AIAgent.Deploy.ImportAll).Run("C:\InterSystems\AIAgent\cls\")</p>
ClassMethod Run(directory As %String) As %Status
{
    set tSC = $$$OK

    // Normalize directory path
    if $extract(directory, *) '= "\" {
        if $extract(directory, *) '= "/" {
            set directory = directory _ "\"
        }
    }

    write "[AIAgent.Deploy] ================================================",!
    write "[AIAgent.Deploy] IRIS Copilot — Class Import & Compile",!
    write "[AIAgent.Deploy] ================================================",!
    write "[AIAgent.Deploy] Source directory: " _ directory,!
    write "[AIAgent.Deploy] Target namespace: " _ $namespace,!
    write !

    // Phase 1: Foundation (no dependencies)
    write "[AIAgent.Deploy] Phase 1: Foundation classes...",!
    set tSC = ..ImportPhase(directory, $lb(
        "AIAgent\Util\JSON.cls",
        "AIAgent\Util\Logger.cls"
    ))
    if $$$ISERR(tSC) quit tSC

    // Phase 2: Data Model
    write "[AIAgent.Deploy] Phase 2: Data Model classes...",!
    set tSC = ..ImportPhase(directory, $lb(
        "AIAgent\Model\Conversation.cls",
        "AIAgent\Model\Message.cls",
        "AIAgent\Model\Generation.cls",
        "AIAgent\Model\GenerationClass.cls",
        "AIAgent\Model\Version.cls",
        "AIAgent\Model\AuditEntry.cls"
    ))
    if $$$ISERR(tSC) quit tSC

    // Phase 3: Engine
    write "[AIAgent.Deploy] Phase 3: Engine classes...",!
    set tSC = ..ImportPhase(directory, $lb(
        "AIAgent\Engine\CodeManager.cls",
        "AIAgent\Engine\ProductionManager.cls",
        "AIAgent\Engine\VersionManager.cls",
        "AIAgent\Engine\TestRunner.cls",
        "AIAgent\Engine\BridgeClient.cls",
        "AIAgent\Engine\Orchestrator.cls"
    ))
    if $$$ISERR(tSC) quit tSC

    // Phase 4: Templates
    write "[AIAgent.Deploy] Phase 4: Template classes...",!
    set tSC = ..ImportPhase(directory, $lb(
        "AIAgent\Templates\BusinessService.cls",
        "AIAgent\Templates\BusinessProcess.cls",
        "AIAgent\Templates\BusinessOperation.cls",
        "AIAgent\Templates\DataTransformation.cls",
        "AIAgent\Templates\RoutingRule.cls",
        "AIAgent\Templates\MessageClass.cls",
        "AIAgent\Templates\Factory.cls"
    ))
    if $$$ISERR(tSC) quit tSC

    // Phase 5: API + UI
    write "[AIAgent.Deploy] Phase 5: API and UI classes...",!
    set tSC = ..ImportPhase(directory, $lb(
        "AIAgent\API\Dispatcher.cls",
        "AIAgent\UI\Chat.cls"
    ))
    if $$$ISERR(tSC) quit tSC

    // Phase 6: Installer
    write "[AIAgent.Deploy] Phase 6: Installer...",!
    set tSC = ..ImportPhase(directory, $lb(
        "AIAgent\Install\Installer.cls"
    ))
    if $$$ISERR(tSC) quit tSC

    write !
    write "[AIAgent.Deploy] ================================================",!
    write "[AIAgent.Deploy] All 24 classes imported and compiled successfully!",!
    write "[AIAgent.Deploy] ================================================",!
    write !
    write "[AIAgent.Deploy] Next steps:",!
    write "[AIAgent.Deploy]   1. Run the installer:",!
    write "[AIAgent.Deploy]      do ##class(AIAgent.Install.Installer).Run()",!
    write "[AIAgent.Deploy]",!
    write "[AIAgent.Deploy]   2. Configure API keys:",!
    write "[AIAgent.Deploy]      do ##class(AIAgent.Install.Installer).Configure(bridgeUrl, anthropicKey, openaiKey, azureEndpoint, azureKey)",!
    write "[AIAgent.Deploy]",!
    write "[AIAgent.Deploy]   3. Start the Node.js bridge (on the bridge server):",!
    write "[AIAgent.Deploy]      cd bridge && npm install && npm start",!
    write !

    quit tSC
}

/// Import and compile a phase of classes.
ClassMethod ImportPhase(directory As %String, files As %List) As %Status [ Private ]
{
    set tSC = $$$OK
    set count = $listlength(files)

    for i = 1:1:count {
        set file = $listget(files, i)
        set fullPath = directory _ file

        // Check file exists
        if '##class(%File).Exists(fullPath) {
            write "  ERROR: File not found: " _ fullPath,!
            set tSC = $$$ERROR($$$GeneralError, "File not found: " _ fullPath)
            quit
        }

        // Extract class name from file path for display
        set className = $replace(file, "\", ".")
        set className = $replace(className, "/", ".")
        set className = $extract(className, 1, $length(className) - 4)  // remove .cls

        write "  Loading " _ className _ " ... "

        set tLoadSC = $system.OBJ.Load(fullPath, "ck-d")
        if $$$ISERR(tLoadSC) {
            write "FAILED",!
            write "    Error: " _ $system.Status.GetErrorText(tLoadSC),!
            set tSC = tLoadSC
            quit
        }
        write "OK",!
    }

    quit tSC
}

/// Verify all 24 AIAgent classes exist and are compiled.
ClassMethod Verify() As %Status
{
    set tSC = $$$OK
    set classes = $lb(
        "AIAgent.Util.JSON",
        "AIAgent.Util.Logger",
        "AIAgent.Model.Conversation",
        "AIAgent.Model.Message",
        "AIAgent.Model.Generation",
        "AIAgent.Model.GenerationClass",
        "AIAgent.Model.Version",
        "AIAgent.Model.AuditEntry",
        "AIAgent.Engine.CodeManager",
        "AIAgent.Engine.ProductionManager",
        "AIAgent.Engine.VersionManager",
        "AIAgent.Engine.TestRunner",
        "AIAgent.Engine.BridgeClient",
        "AIAgent.Engine.Orchestrator",
        "AIAgent.Templates.BusinessService",
        "AIAgent.Templates.BusinessProcess",
        "AIAgent.Templates.BusinessOperation",
        "AIAgent.Templates.DataTransformation",
        "AIAgent.Templates.RoutingRule",
        "AIAgent.Templates.MessageClass",
        "AIAgent.Templates.Factory",
        "AIAgent.API.Dispatcher",
        "AIAgent.UI.Chat",
        "AIAgent.Install.Installer"
    )

    set total = $listlength(classes)
    set okCount = 0
    set failCount = 0

    write "[AIAgent.Deploy] Verifying all " _ total _ " classes...",!

    for i = 1:1:total {
        set className = $listget(classes, i)
        set dots = $justify("", 40 - $length(className))
        set dots = $translate(dots, " ", ".")
        write "  " _ className _ " " _ dots _ " "

        if ##class(%Dictionary.ClassDefinition).%ExistsId(className) {
            write "OK",!
            set okCount = okCount + 1
        } else {
            write "MISSING",!
            set failCount = failCount + 1
            set tSC = $$$ERROR($$$GeneralError, "Class not found: " _ className)
        }
    }

    write !
    if failCount = 0 {
        write "[AIAgent.Deploy] All " _ total _ " classes verified. Ready for installation.",!
    } else {
        write "[AIAgent.Deploy] WARNING: " _ failCount _ " class(es) missing. Re-import required.",!
    }

    quit tSC
}

/// Quick deploy: import, compile, install, and verify in one step.
/// <p>Example: do ##class(AIAgent.Deploy.ImportAll).QuickDeploy("C:\InterSystems\AIAgent\cls\")</p>
ClassMethod QuickDeploy(directory As %String) As %Status
{
    set tSC = $$$OK

    // Step 1: Import all classes
    set tSC = ..Run(directory)
    if $$$ISERR(tSC) {
        write "[AIAgent.Deploy] Import failed. Aborting.",!
        quit tSC
    }

    // Step 2: Verify
    set tSC = ..Verify()
    if $$$ISERR(tSC) {
        write "[AIAgent.Deploy] Verification failed. Aborting.",!
        quit tSC
    }

    // Step 3: Run installer
    write !
    write "[AIAgent.Deploy] Running installer...",!
    set tSC = ##class(AIAgent.Install.Installer).Run()
    if $$$ISERR(tSC) {
        write "[AIAgent.Deploy] Installation failed.",!
        quit tSC
    }

    write !
    write "[AIAgent.Deploy] ================================================",!
    write "[AIAgent.Deploy] Quick Deploy complete!",!
    write "[AIAgent.Deploy] ================================================",!
    write "[AIAgent.Deploy] Configure API keys to finish setup:",!
    write "[AIAgent.Deploy]   do ##class(AIAgent.Install.Installer).Configure(...)",!
    write "[AIAgent.Deploy] ================================================",!

    quit tSC
}

}
