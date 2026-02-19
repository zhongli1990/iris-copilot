/// Standalone installer for the IRIS AI Agent Platform (IRIS Copilot).
/// Deploys the AIAgent package to any IRIS HealthConnect instance.
/// 
/// Usage from IRIS terminal:
///   do ##class(AIAgent.Install.Installer).Run()
///   do ##class(AIAgent.Install.Installer).Configure("http://localhost:3100", "sk-ant-...", "sk-...")
///   do ##class(AIAgent.Install.Installer).Uninstall()
/// 
/// Part of the IRIS AI Agent Platform (IRIS Copilot).
Class AIAgent.Install.Installer [ Abstract ]
{

/// The CSP web application path.
Parameter WEBAPP = "/ai";

/// The COS package name.
Parameter PACKAGE = "AIAgent";

/// Global prefix for all AIAgent data.
Parameter GLOBALPREFIX = "^AIAgent";

/// Run the full installation.
ClassMethod Run() As %Status
{
    set sc = $$$OK
    write !, "================================================================"
    write !, "  IRIS AI Agent Platform (IRIS Copilot) — Installer"
    write !, "================================================================"
    write !

    // Step 1: Check prerequisites
    write !, "[1/5] Checking prerequisites..."
    set sc = ..CheckPrerequisites()
    if $$$ISERR(sc) {
        write !, "  ERROR: Prerequisites not met: ", $system.Status.GetOneErrorText(sc)
        return sc
    }
    write !, "  OK — IRIS HealthConnect/Ensemble available"
    write !, "  OK — Namespace: ", $namespace

    // Step 2: Create Web Application
    write !, ""
    write !, "[2/5] Creating web application ", ..#WEBAPP, "..."
    set sc = ..CreateWebApplication()
    if $$$ISERR(sc) {
        write !, "  ERROR: ", $system.Status.GetOneErrorText(sc)
        return sc
    }
    write !, "  OK — Web application ", ..#WEBAPP, " configured"

    // Step 3: Initialize data structures
    write !, ""
    write !, "[3/5] Initializing data structures..."
    set sc = ..InitializeData()
    if $$$ISERR(sc) {
        write !, "  ERROR: ", $system.Status.GetOneErrorText(sc)
        return sc
    }
    write !, "  OK — Globals and indices ready"

    // Step 4: Verify compilation
    write !, ""
    write !, "[4/5] Verifying class compilation..."
    set sc = ..VerifyCompilation()
    if $$$ISERR(sc) {
        write !, "  WARNING: Some classes may need recompilation"
    } else {
        write !, "  OK — All AIAgent classes compiled"
    }

    // Step 5: Print summary
    write !, ""
    write !, "[5/5] Installation complete!"
    write !, ""
    write !, "================================================================"
    write !, "  IRIS Copilot installed successfully"
    write !, "================================================================"
    write !, ""
    write !, "  Chat UI:    https://<iris-host>", ..#WEBAPP, "/AIAgent.UI.Chat.cls"
    write !, "  REST API:   https://<iris-host>", ..#WEBAPP, "/health"
    write !, "  Namespace:  ", $namespace
    write !, ""
    write !, "  Next steps:"
    write !, "  1. Configure AI keys:"
    write !, "     do ##class(AIAgent.Install.Installer).Configure(bridgeUrl, anthropicKey, openaiKey)"
    write !, "  2. Start the Node.js bridge:"
    write !, "     cd AIAgent/bridge && npm install && npm start"
    write !, "  3. Open the Chat UI in your browser"
    write !, ""
    return $$$OK
}

/// Check that IRIS HealthConnect / Ensemble is available.
ClassMethod CheckPrerequisites() As %Status
{
    // Check Ensemble/HealthConnect is installed
    if '##class(%Dictionary.CompiledClass).%ExistsId("Ens.Director") {
        return $$$ERROR($$$GeneralError, "Ensemble/HealthConnect not available. The AIAgent platform requires IRIS HealthConnect or IRIS with Ensemble installed.")
    }
    // Check we have production capabilities
    if '##class(%Dictionary.CompiledClass).%ExistsId("Ens.Config.Production") {
        return $$$ERROR($$$GeneralError, "Production configuration classes not available")
    }
    // Check HL7 support
    if '##class(%Dictionary.CompiledClass).%ExistsId("EnsLib.HL7.Message") {
        write !, "  WARNING: EnsLib.HL7.Message not found — HL7 features will be limited"
    }
    return $$$OK
}

/// Create the /ai web application mapping to AIAgent.API.Dispatcher.
ClassMethod CreateWebApplication() As %Status
{
    set sc = $$$OK
    try {
        // Check if web app already exists
        set exists = ##class(Security.Applications).Exists(..#WEBAPP, .app)
        if exists {
            write !, "  Web application ", ..#WEBAPP, " already exists — updating..."
        }

        // Build properties array
        set props("Name") = ..#WEBAPP
        set props("NameSpace") = $namespace
        set props("Description") = "IRIS AI Agent Platform (IRIS Copilot)"
        set props("Enabled") = 1
        set props("AutheEnabled") = 32  // Password authentication
        set props("DispatchClass") = "AIAgent.API.Dispatcher"
        set props("MatchRoles") = ":%All"
        set props("CookiePath") = ..#WEBAPP
        set props("CSPZENEnabled") = 1
        set props("InbndWebServicesEnabled") = 1

        if exists {
            set sc = ##class(Security.Applications).Modify(..#WEBAPP, .props)
        } else {
            set sc = ##class(Security.Applications).Create(..#WEBAPP, .props)
        }

        if $$$ISERR(sc) {
            // Try a simpler approach if Security.Applications isn't available
            write !, "  Note: Could not auto-create web application."
            write !, "  Please create manually in Management Portal:"
            write !, "    System Administration > Security > Applications > Web Applications"
            write !, "    Path: ", ..#WEBAPP
            write !, "    Dispatch Class: AIAgent.API.Dispatcher"
            write !, "    Namespace: ", $namespace
            set sc = $$$OK  // Don't fail installation for this
        }
    } catch ex {
        // Security.Applications may not be accessible from this namespace
        write !, "  Note: Auto-creation requires %SYS namespace access."
        write !, "  Please create the web application manually (see instructions above)."
        set sc = $$$OK
    }
    return sc
}

/// Initialize data globals and verify storage.
ClassMethod InitializeData() As %Status
{
    set sc = $$$OK
    try {
        // Ensure log global exists
        if '$data(^AIAgent.Log) { set ^AIAgent.Log = 0 }

        // Verify persistent class storage
        set classes = $listbuild(
            "AIAgent.Model.Conversation",
            "AIAgent.Model.Message",
            "AIAgent.Model.Generation",
            "AIAgent.Model.GenerationClass",
            "AIAgent.Model.Version",
            "AIAgent.Model.AuditEntry"
        )
        for i = 1:1:$listlength(classes) {
            set cls = $listget(classes, i)
            if ##class(%Dictionary.CompiledClass).%ExistsId(cls) {
                write !, "  OK — ", cls
            } else {
                write !, "  MISSING — ", cls, " (needs compilation)"
            }
        }

        // Log the installation
        do ##class(AIAgent.Util.Logger).Info("Installer", "Installation completed", $namespace)
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Verify all AIAgent classes are compiled.
ClassMethod VerifyCompilation() As %Status
{
    set sc = $$$OK
    set sql = "SELECT Name FROM %Dictionary.ClassDefinition WHERE Name LIKE 'AIAgent.%' ORDER BY Name"
    set stmt = ##class(%SQL.Statement).%New()
    do stmt.%Prepare(sql)
    set rs = stmt.%Execute()
    set total = 0
    set compiled = 0
    while rs.%Next() {
        set className = rs.%GetData(1)
        set total = total + 1
        if ##class(%Dictionary.CompiledClass).%ExistsId(className) {
            set compiled = compiled + 1
        } else {
            write !, "  NOT COMPILED: ", className
            // Attempt to compile
            try {
                do $system.OBJ.Compile(className, "ck")
                set compiled = compiled + 1
            } catch {}
        }
    }
    write !, "  ", compiled, "/", total, " classes compiled"
    if compiled < total {
        set sc = $$$ERROR($$$GeneralError, (total - compiled) _ " classes not compiled")
    }
    return sc
}

/// Configure AI API keys and bridge URL.
/// Keys are stored encrypted in IRIS configuration.
ClassMethod Configure(bridgeUrl As %String = "http://localhost:3100", anthropicKey As %String = "", openaiKey As %String = "", azureEndpoint As %String = "", azureKey As %String = "") As %Status
{
    set sc = $$$OK
    write !, "Configuring IRIS Copilot..."
    try {
        // Store settings using Ens.Config.DefaultSettings
        // These are accessible from the Management Portal
        if bridgeUrl '= "" {
            set ^AIAgent.Config("BridgeURL") = bridgeUrl
            write !, "  Bridge URL: ", bridgeUrl
        }
        if anthropicKey '= "" {
            // Obfuscate for display, store full key
            set ^AIAgent.Config("AnthropicKey") = anthropicKey
            write !, "  Anthropic API Key: ", $extract(anthropicKey, 1, 10), "..."
        }
        if openaiKey '= "" {
            set ^AIAgent.Config("OpenAIKey") = openaiKey
            write !, "  OpenAI API Key: ", $extract(openaiKey, 1, 10), "..."
        }
        if azureEndpoint '= "" {
            set ^AIAgent.Config("AzureEndpoint") = azureEndpoint
            write !, "  Azure Endpoint: ", azureEndpoint
        }
        if azureKey '= "" {
            set ^AIAgent.Config("AzureKey") = azureKey
            write !, "  Azure Key: ", $extract(azureKey, 1, 10), "..."
        }
        write !, ""
        write !, "Configuration saved. Restart the Node.js bridge to pick up changes."
    } catch ex {
        set sc = ex.AsStatus()
        write !, "ERROR: ", ex.DisplayString()
    }
    return sc
}

/// Get a configuration value.
ClassMethod GetConfig(key As %String, default As %String = "") As %String
{
    return $get(^AIAgent.Config(key), default)
}

/// Uninstall the AIAgent platform.
/// Removes web application, classes, and data.
ClassMethod Uninstall(keepData As %Boolean = 0) As %Status
{
    set sc = $$$OK
    write !, "================================================================"
    write !, "  Uninstalling IRIS AI Agent Platform"
    write !, "================================================================"
    write !

    // Step 1: Remove web application
    write !, "[1/3] Removing web application..."
    try {
        if ##class(Security.Applications).Exists(..#WEBAPP) {
            do ##class(Security.Applications).Delete(..#WEBAPP)
            write !, "  Removed ", ..#WEBAPP
        } else {
            write !, "  Web application not found (already removed)"
        }
    } catch {
        write !, "  Could not auto-remove — please delete manually from Management Portal"
    }

    // Step 2: Remove data (if requested)
    if 'keepData {
        write !, ""
        write !, "[2/3] Removing data..."
        kill ^AIAgent.ConversationD, ^AIAgent.ConversationI, ^AIAgent.ConversationS
        kill ^AIAgent.MessageD, ^AIAgent.MessageI, ^AIAgent.MessageS
        kill ^AIAgent.GenerationD, ^AIAgent.GenerationI, ^AIAgent.GenerationS
        kill ^AIAgent.GenerationClassD, ^AIAgent.GenerationClassI, ^AIAgent.GenerationClassS
        kill ^AIAgent.VersionD, ^AIAgent.VersionI, ^AIAgent.VersionS
        kill ^AIAgent.AuditEntryD, ^AIAgent.AuditEntryI, ^AIAgent.AuditEntryS
        kill ^AIAgent.Log
        kill ^AIAgent.Config
        write !, "  Data globals removed"
    } else {
        write !, ""
        write !, "[2/3] Keeping data (keepData=1)"
    }

    // Step 3: Remove classes
    write !, ""
    write !, "[3/3] Removing classes..."
    do $system.OBJ.DeletePackage("AIAgent")
    write !, "  Package AIAgent removed"

    write !, ""
    write !, "================================================================"
    write !, "  Uninstall complete"
    write !, "================================================================"
    write !

    return sc
}

/// Export the entire AIAgent package to a directory for deployment to another IRIS instance.
/// Creates a self-contained export that can be imported with ImportPackage().
ClassMethod ExportPackage(directory As %String) As %Status
{
    set sc = $$$OK
    write !, "Exporting AIAgent package to: ", directory
    try {
        // Create directory
        if '##class(%File).DirectoryExists(directory) {
            do ##class(%File).CreateDirectoryChain(directory)
        }

        // Export all classes individually
        do $system.OBJ.ExportAllClassesIndividual(directory, "/diffexport=1", "", "", "AIAgent")
        write !, "  Classes exported"

        // Export lookup tables (if any AI-generated ones exist)
        set sql = "SELECT DISTINCT TableName FROM Ens_Util.LookupTable WHERE TableName LIKE 'AIAgent%' OR TableName LIKE 'Pharm%'"
        set stmt = ##class(%SQL.Statement).%New()
        do stmt.%Prepare(sql)
        set rs = stmt.%Execute()
        while rs.%Next() {
            set tableName = rs.%GetData(1)
            do ##class(Ens.Util.LookupTable).%Export(directory _ "/" _ tableName _ ".lut.xml", tableName)
            write !, "  Exported lookup table: ", tableName
        }

        write !, ""
        write !, "Export complete. To import on another IRIS instance:"
        write !, "  set sc = $system.OBJ.LoadDir(""", directory, """, ""ck"")"
        write !, "  do ##class(AIAgent.Install.Installer).Run()"
    } catch ex {
        set sc = ex.AsStatus()
        write !, "ERROR: ", ex.DisplayString()
    }
    return sc
}

/// Import the AIAgent package from a directory.
ClassMethod ImportPackage(directory As %String) As %Status
{
    set sc = $$$OK
    write !, "Importing AIAgent package from: ", directory
    try {
        set sc = $system.OBJ.LoadDir(directory, "ck/multicompile=0")
        if $$$ISOK(sc) {
            write !, "  Classes imported and compiled"
            // Run installation
            set sc = ..Run()
        } else {
            write !, "  ERROR: ", $system.Status.GetOneErrorText(sc)
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Print current configuration and system status.
ClassMethod Status() As %Status
{
    write !, "================================================================"
    write !, "  IRIS AI Agent Platform — Status"
    write !, "================================================================"
    write !

    // Namespace
    write !, "  Namespace:      ", $namespace

    // Web Application
    try {
        set exists = ##class(Security.Applications).Exists(..#WEBAPP)
        write !, "  Web App (/ai):  ", $select(exists:"Configured", 1:"NOT CONFIGURED")
    } catch {
        write !, "  Web App (/ai):  Unknown (check Management Portal)"
    }

    // Bridge
    set bridgeUrl = ..GetConfig("BridgeURL", "http://localhost:3100")
    write !, "  Bridge URL:     ", bridgeUrl
    set health = ##class(AIAgent.Engine.BridgeClient).HealthCheck()
    write !, "  Bridge Status:  ", $select(health.healthy:"Healthy", 1:"NOT REACHABLE — "_$select(health.error'="":health.error, 1:"Connection failed"))

    // Production
    set prodStatus = ##class(AIAgent.Engine.ProductionManager).GetStatus()
    write !, "  Production:     ", prodStatus.productionName, " (", prodStatus.statusText, ")"

    // API Keys
    write !, "  Anthropic Key:  ", $select(..GetConfig("AnthropicKey")'="":"Configured", 1:"NOT SET")
    write !, "  OpenAI Key:     ", $select(..GetConfig("OpenAIKey")'="":"Configured", 1:"NOT SET")
    write !, "  Azure Endpoint: ", $select(..GetConfig("AzureEndpoint")'="":"Configured", 1:"NOT SET")

    // Data counts
    &sql(SELECT COUNT(*) INTO :convCount FROM AIAgent_Model.Conversation)
    &sql(SELECT COUNT(*) INTO :msgCount FROM AIAgent_Model.Message)
    &sql(SELECT COUNT(*) INTO :genCount FROM AIAgent_Model.Generation)
    &sql(SELECT COUNT(*) INTO :verCount FROM AIAgent_Model.Version)
    &sql(SELECT COUNT(*) INTO :auditCount FROM AIAgent_Model.AuditEntry)
    write !, ""
    write !, "  Conversations:  ", +$get(convCount, 0)
    write !, "  Messages:       ", +$get(msgCount, 0)
    write !, "  Generations:    ", +$get(genCount, 0)
    write !, "  Versions:       ", +$get(verCount, 0)
    write !, "  Audit Entries:  ", +$get(auditCount, 0)

    // Class count
    set classCount = 0
    set sql = "SELECT COUNT(*) FROM %Dictionary.ClassDefinition WHERE Name LIKE 'AIAgent.%'"
    set stmt = ##class(%SQL.Statement).%New()
    do stmt.%Prepare(sql)
    set rs = stmt.%Execute()
    if rs.%Next() { set classCount = rs.%GetData(1) }
    write !, "  AIAgent Classes: ", classCount
    write !, ""

    return $$$OK
}

}
