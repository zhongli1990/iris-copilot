/// Core engine: Manages IRIS HealthConnect production configuration and lifecycle.
/// Provides methods to inspect, modify, start/stop, and monitor productions.
/// 
/// Uses IRIS Ensemble APIs: Ens.Director, Ens.Config.Production, Ens.Config.Item.
/// Production status codes: 1=Running, 2=Stopped, 3=Suspended, 4=Troubled.
/// 
/// Part of the IRIS AI Agent Platform (IRIS Copilot).
Class AIAgent.Engine.ProductionManager [ Abstract ]
{

/// Get the current production name and running status.
ClassMethod GetStatus() As %DynamicObject
{
    set result = ##class(%DynamicObject).%New()
    try {
        do ##class(Ens.Director).GetProductionStatus(.prodName, .prodStatus)
        set result.productionName = $get(prodName, "")
        set result.statusCode = $get(prodStatus, 0)
        set result.statusText = $case(+$get(prodStatus,0),
            1:"Running",
            2:"Stopped",
            3:"Suspended",
            4:"Troubled",
            :"Unknown")
        set result.namespace = $namespace
    } catch ex {
        set result.error = ex.DisplayString()
    }
    return result
}

/// Get the full production topology as structured JSON.
/// Returns all business hosts with their class names, adapter types, settings, and categories.
ClassMethod GetTopology() As %DynamicObject
{
    set result = ##class(%DynamicObject).%New()
    set hosts = ##class(%DynamicArray).%New()
    try {
        // Get production status
        do ##class(Ens.Director).GetProductionStatus(.prodName, .prodStatus)
        set result.productionName = $get(prodName, "")
        set result.statusCode = $get(prodStatus, 0)

        // Open the production definition
        if prodName '= "" {
            set prodDef = ##class(Ens.Config.Production).%OpenId(prodName)
            if $isobject(prodDef) {
                set result.description = prodDef.Description
                // Iterate all items (business hosts)
                for i = 1:1:prodDef.Items.Count() {
                    set item = prodDef.Items.GetAt(i)
                    set host = ##class(%DynamicObject).%New()
                    set host.name = item.Name
                    set host.className = item.ClassName
                    set host.category = item.Category
                    set host.enabled = item.Enabled
                    set host.comment = item.Comment
                    // Determine host type from superclass
                    set host.hostType = ..GetHostType(item.ClassName)
                    // Get adapter if applicable
                    try {
                        set host.adapter = $parameter(item.ClassName, "ADAPTER")
                    } catch {
                        set host.adapter = ""
                    }
                    // Get settings as key-value pairs
                    set settingsObj = ##class(%DynamicObject).%New()
                    if item.Settings '= "" {
                        set settings = item.Settings
                        for s = 1:1:$length(settings, ",") {
                            set pair = $piece(settings, ",", s)
                            if pair [ "=" {
                                set sName = $piece(pair, "=", 1)
                                set sValue = $piece(pair, "=", 2, *)
                                do settingsObj.%Set(sName, sValue)
                            }
                        }
                    }
                    set host.settings = settingsObj
                    do hosts.%Push(host)
                }
            }
        }
    } catch ex {
        set result.error = ex.DisplayString()
    }
    set result.hosts = hosts
    set result.hostCount = hosts.%Size()
    return result
}

/// Determine the host type (BusinessService, BusinessProcess, BusinessOperation, Router)
/// by checking the class hierarchy.
ClassMethod GetHostType(className As %String) As %String [ Private ]
{
    try {
        if $classmethod(className, "%IsA", "Ens.BusinessService") return "BusinessService"
        if $classmethod(className, "%IsA", "Ens.BusinessProcess") return "BusinessProcess"
        if $classmethod(className, "%IsA", "Ens.BusinessOperation") return "BusinessOperation"
        if $classmethod(className, "%IsA", "EnsLib.HL7.MsgRouter.RoutingEngine") return "Router"
    } catch {
        // Class may not exist or not extend Ens classes
    }
    return "Unknown"
}

/// Add a new business host to the production.
/// config expects: {name, className, category, enabled, settings:{key:val,...}, comment}
ClassMethod AddBusinessHost(config As %DynamicObject) As %Status
{
    quit ..EnsureBusinessHost(config, .opResult)
}

/// Idempotent add host with structured outcome for demo/runtime reporting.
ClassMethod EnsureBusinessHost(config As %DynamicObject, ByRef opResult As %DynamicObject) As %Status
{
    set opResult = ##class(%DynamicObject).%New()
    set sc = $$$OK
    try {
        if '$isobject(config) {
            return $$$ERROR($$$GeneralError, "Host config is required")
        }
        set hostName = config.%Get("name")
        set className = config.%Get("className")
        if hostName = "" {
            return $$$ERROR($$$GeneralError, "Host name is required")
        }
        if className = "" {
            return $$$ERROR($$$GeneralError, "Host className is required")
        }

        do ##class(Ens.Director).GetProductionStatus(.prodName, .prodStatus)
        if prodName = "" {
            return $$$ERROR($$$GeneralError, "No production found in namespace")
        }
        set prodDef = ##class(Ens.Config.Production).%OpenId(prodName)
        if '$isobject(prodDef) {
            return $$$ERROR($$$GeneralError, "Cannot open production "_prodName)
        }

        for i = 1:1:prodDef.Items.Count() {
            set existing = prodDef.Items.GetAt(i)
            if existing.Name = hostName {
                set opResult.action = "add"
                set opResult.hostName = hostName
                set opResult.className = existing.ClassName
                set opResult.status = "exists"
                set opResult.enabled = +$get(existing.Enabled)
                set opResult.category = $get(existing.Category)
                set opResult.message = "Host already exists; no mutation applied."
                return $$$OK
            }
        }

        set item = ##class(Ens.Config.Item).%New()
        set item.Name = hostName
        set item.ClassName = className
        set item.Category = $select(config.%Get("category")'="":config.%Get("category"), 1:"AIGenerated")
        set enabledRequested = $select(config.%Get("enabled")'="":+config.%Get("enabled"), 1:1)
        set item.Comment = $select(config.%Get("comment")'="":config.%Get("comment"), 1:"Added by IRIS CoPilot")

        if $isobject(config.%Get("settings")) {
            set sc = ..ApplySettingsObject(.item, config.%Get("settings"), 0)
            if $$$ISERR(sc) {
                return sc
            }
        }

        do prodDef.Items.Insert(item)
        set sc = prodDef.%Save()
        if $$$ISERR(sc) {
            return sc
        }

        // Apply runtime enable/disable via Director API (safer than direct assignment on Ens.Config.Item).
        set scEnable = ##class(Ens.Director).EnableConfigItem(hostName, enabledRequested, 1)
        if $$$ISERR(scEnable) {
            // Keep this non-fatal for demo flow: config exists and was saved; capture warning only.
            do ##class(AIAgent.Util.Logger).Error("ProductionManager", "EnableConfigItem warning", $system.Status.GetOneErrorText(scEnable))
        }

        do ##class(AIAgent.Model.AuditEntry).LogSuccess("deploy", hostName, "Added to production "_prodName)
        do ##class(AIAgent.Util.Logger).Info("ProductionManager", "Added host", hostName)

        set opResult.action = "add"
        set opResult.hostName = hostName
        set opResult.className = className
        set opResult.status = "created"
        set opResult.enabled = enabledRequested
        set opResult.category = item.Category
        set opResult.message = "Host created."
    } catch ex {
        set sc = ex.AsStatus()
        do ##class(AIAgent.Model.AuditEntry).LogFailure("deploy", $get(hostName), ex.DisplayString())
    }
    return sc
}

/// Remove a business host from the production by name.
ClassMethod RemoveBusinessHost(itemName As %String) As %Status
{
    quit ..RemoveBusinessHostEx(itemName, .opResult)
}

/// Idempotent remove host with structured outcome.
ClassMethod RemoveBusinessHostEx(itemName As %String, ByRef opResult As %DynamicObject) As %Status
{
    set opResult = ##class(%DynamicObject).%New()
    set sc = $$$OK
    try {
        if itemName = "" {
            return $$$ERROR($$$GeneralError, "Host name is required")
        }
        do ##class(Ens.Director).GetProductionStatus(.prodName, .prodStatus)
        set prodDef = ##class(Ens.Config.Production).%OpenId(prodName)
        if '$isobject(prodDef) {
            return $$$ERROR($$$GeneralError, "Cannot open production")
        }

        set found = 0
        for i = 1:1:prodDef.Items.Count() {
            if prodDef.Items.GetAt(i).Name = itemName {
                do prodDef.Items.RemoveAt(i)
                set found = 1
                quit
            }
        }
        if 'found {
            set opResult.action = "remove"
            set opResult.hostName = itemName
            set opResult.status = "not_found"
            set opResult.message = "Host was not present; no mutation applied."
            return $$$OK
        }

        set sc = prodDef.%Save()
        if $$$ISERR(sc) {
            return sc
        }
        do ##class(AIAgent.Model.AuditEntry).LogSuccess("delete", itemName, "Removed from production")
        do ##class(AIAgent.Util.Logger).Info("ProductionManager", "Removed host", itemName)

        set opResult.action = "remove"
        set opResult.hostName = itemName
        set opResult.status = "removed"
        set opResult.message = "Host removed."
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Update settings for an existing business host.
/// settings is a %DynamicObject of {key: value} pairs.
ClassMethod UpdateHostSettings(itemName As %String, settings As %DynamicObject) As %Status
{
    quit ..UpdateHostSettingsEx(itemName, settings, .opResult)
}

/// Update host settings with structured per-item outcome.
/// Special key handling:
/// - Enabled => updates item.Enabled property
/// - Comment => updates item.Comment property
ClassMethod UpdateHostSettingsEx(itemName As %String, settings As %DynamicObject, ByRef opResult As %DynamicObject) As %Status
{
    set opResult = ##class(%DynamicObject).%New()
    set sc = $$$OK
    try {
        if (itemName = "") || ('$isobject(settings)) {
            return $$$ERROR($$$GeneralError, "Host name and settings object are required")
        }
        do ##class(Ens.Director).GetProductionStatus(.prodName, .prodStatus)
        set prodDef = ##class(Ens.Config.Production).%OpenId(prodName)
        if '$isobject(prodDef) {
            return $$$ERROR($$$GeneralError, "Cannot open production")
        }

        set found = 0
        for i = 1:1:prodDef.Items.Count() {
            set item = prodDef.Items.GetAt(i)
            if item.Name = itemName {
                set found = 1
                set applied = ##class(%DynamicObject).%New()
                set iter = settings.%GetIterator()
                while iter.%GetNext(.key, .val) {
                    set keyLow = $zconvert(key, "L")
                    if keyLow = "enabled" {
                        // Apply Enabled as a runtime config-item toggle via Director.
                        set scEnable = ##class(Ens.Director).EnableConfigItem(itemName, +val, 1)
                        if $$$ISERR(scEnable) {
                            return scEnable
                        }
                        set applied.Enabled = +val
                    } elseif keyLow = "comment" {
                        set item.Comment = val
                        set applied.Comment = val
                    } else {
                        set scSet = ..SetItemSetting(.item, key, val)
                        if $$$ISERR(scSet) {
                            return scSet
                        }
                        do applied.%Set(key, val)
                    }
                }
                set opResult.applied = applied
                quit
            }
        }

        if 'found {
            set opResult.action = "settings"
            set opResult.hostName = itemName
            set opResult.status = "not_found"
            set opResult.message = "Host was not found; no mutation applied."
            return $$$OK
        }

        set sc = prodDef.%Save()
        if $$$ISERR(sc) {
            return sc
        }

        set opResult.action = "settings"
        set opResult.hostName = itemName
        set opResult.status = "updated"
        set opResult.message = "Host settings updated."
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

ClassMethod SetItemSetting(ByRef item, key As %String, val As %String) As %Status [ Private ]
{
    try {
        set item.Settings(key) = val
    } catch ex {
        return ex.AsStatus()
    }
    return $$$OK
}

ClassMethod ApplySettingsObject(ByRef item, settings As %DynamicObject, clearExisting As %Boolean = 0) As %Status [ Private ]
{
    if '$isobject(settings) {
        return $$$OK
    }
    try {
        if clearExisting {
            kill item.Settings
        }
        set iter = settings.%GetIterator()
        while iter.%GetNext(.key, .val) {
            if key = "" continue
            set item.Settings(key) = val
        }
    } catch ex {
        return ex.AsStatus()
    }
    return $$$OK
}

ClassMethod SettingsStringToObject(settingsStr As %String) As %DynamicObject [ Private ]
{
    set out = ##class(%DynamicObject).%New()
    if settingsStr = "" quit out
    for s = 1:1:$length(settingsStr, ",") {
        set pair = $piece(settingsStr, ",", s)
        if pair [ "=" {
            set sName = $piece(pair, "=", 1)
            set sValue = $piece(pair, "=", 2, *)
            do out.%Set(sName, sValue)
        }
    }
    quit out
}

ClassMethod SettingsObjectToString(settings As %DynamicObject) As %String [ Private ]
{
    set settingsStr = ""
    if '$isobject(settings) quit settingsStr
    set iter = settings.%GetIterator()
    while iter.%GetNext(.key, .val) {
        if key = "" continue
        set:settingsStr'="" settingsStr = settingsStr _ ","
        set settingsStr = settingsStr _ key _ "=" _ val
    }
    quit settingsStr
}

/// Start the production.
ClassMethod StartProduction(productionName As %String = "") As %Status
{
    set sc = $$$OK
    try {
        if productionName = "" {
            // Try to start the default production
            do ##class(Ens.Director).GetProductionStatus(.prodName, .prodStatus)
            set productionName = prodName
        }
        if productionName = "" {
            return $$$ERROR($$$GeneralError, "No production name specified and no default found")
        }
        set sc = ##class(Ens.Director).StartProduction(productionName)
        if $$$ISOK(sc) {
            do ##class(AIAgent.Model.AuditEntry).LogSuccess("start", productionName)
        } else {
            do ##class(AIAgent.Model.AuditEntry).LogFailure("start", productionName, $system.Status.GetOneErrorText(sc))
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Stop the production.
ClassMethod StopProduction(timeout As %Integer = 300) As %Status
{
    set sc = $$$OK
    try {
        set sc = ##class(Ens.Director).StopProduction(timeout, 1)
        do ##class(Ens.Director).GetProductionStatus(.prodName, .prodStatus)
        if $$$ISOK(sc) {
            do ##class(AIAgent.Model.AuditEntry).LogSuccess("stop", $get(prodName,""))
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Update a running production (apply config changes without full restart).
ClassMethod UpdateProduction() As %Status
{
    set sc = $$$OK
    try {
        set sc = ##class(Ens.Director).UpdateProduction()
        if $$$ISOK(sc) {
            do ##class(AIAgent.Model.AuditEntry).LogSuccess("configure", "Production", "Live update applied")
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Restart a specific business host item by name.
ClassMethod RestartHost(itemName As %String) As %Status
{
    set sc = $$$OK
    try {
        // Disable then re-enable to restart
        set sc = ##class(Ens.Director).EnableConfigItem(itemName, 0, 1)
        if $$$ISOK(sc) {
            hang 1  // brief pause
            set sc = ##class(Ens.Director).EnableConfigItem(itemName, 1, 1)
        }
        if $$$ISOK(sc) {
            do ##class(AIAgent.Util.Logger).Info("ProductionManager", "Restarted host", itemName)
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Get message queue depths for all hosts.
ClassMethod GetQueueCounts() As %DynamicArray
{
    set arr = ##class(%DynamicArray).%New()
    try {
        set sql = "SELECT ConfigName, COUNT(*) As QueueDepth FROM Ens.MessageHeader WHERE Status = 6 GROUP BY ConfigName HAVING COUNT(*) > 0 ORDER BY QueueDepth DESC"
        set stmt = ##class(%SQL.Statement).%New()
        do stmt.%Prepare(sql)
        set rs = stmt.%Execute()
        while rs.%Next() {
            set obj = ##class(%DynamicObject).%New()
            set obj.hostName = rs.%GetData(1)
            set obj.queueDepth = rs.%GetData(2)
            do arr.%Push(obj)
        }
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("ProductionManager", "GetQueueCounts failed", ex.DisplayString())
    }
    return arr
}

/// Get recent event log entries.
ClassMethod GetEventLog(count As %Integer = 50, configName As %String = "") As %DynamicArray
{
    set arr = ##class(%DynamicArray).%New()
    try {
        set sql = "SELECT TOP ? ID, ConfigName, TimeLogged, Type, Text FROM Ens_Util.Log"
        if configName '= "" {
            set sql = sql _ " WHERE ConfigName = ?"
        }
        set sql = sql _ " ORDER BY ID DESC"
        set stmt = ##class(%SQL.Statement).%New()
        do stmt.%Prepare(sql)
        set rs = $select(configName'="":stmt.%Execute(count, configName), 1:stmt.%Execute(count))
        while rs.%Next() {
            set obj = ##class(%DynamicObject).%New()
            set obj.id = rs.%GetData(1)
            set obj.configName = rs.%GetData(2)
            set obj.timeLogged = rs.%GetData(3)
            set obj.type = rs.%GetData(4)
            set obj.text = rs.%GetData(5)
            do arr.%Push(obj)
        }
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("ProductionManager", "GetEventLog failed", ex.DisplayString())
    }
    return arr
}

/// Get message trace for a specific session or message header ID.
ClassMethod GetMessageTrace(headerId As %Integer) As %DynamicObject
{
    set result = ##class(%DynamicObject).%New()
    try {
        set header = ##class(Ens.MessageHeader).%OpenId(headerId)
        if '$isobject(header) {
            set result.error = "Message header "_headerId_" not found"
            return result
        }
        set result.id = header.%Id()
        set result.status = header.Status
        set result.sourceConfigName = header.SourceConfigName
        set result.targetConfigName = header.TargetConfigName
        set result.timeCreated = header.TimeCreated
        set result.timeProcessed = header.TimeProcessed
        set result.messageBodyClassName = header.MessageBodyClassName
        set result.sessionId = header.SessionId
        set result.isError = header.IsError
        set result.errorStatus = $select(header.IsError:$system.Status.GetOneErrorText(header.ErrorStatus), 1:"")
    } catch ex {
        set result.error = ex.DisplayString()
    }
    return result
}

}
