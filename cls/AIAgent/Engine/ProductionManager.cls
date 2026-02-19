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
    set sc = $$$OK
    try {
        do ##class(Ens.Director).GetProductionStatus(.prodName, .prodStatus)
        if prodName = "" {
            return $$$ERROR($$$GeneralError, "No production found in namespace")
        }
        set prodDef = ##class(Ens.Config.Production).%OpenId(prodName)
        if '$isobject(prodDef) {
            return $$$ERROR($$$GeneralError, "Cannot open production "_prodName)
        }

        // Check for duplicate
        for i = 1:1:prodDef.Items.Count() {
            if prodDef.Items.GetAt(i).Name = config.name {
                return $$$ERROR($$$GeneralError, "Host '"_config.name_"' already exists in production")
            }
        }

        // Create new item
        set item = ##class(Ens.Config.Item).%New()
        set item.Name = config.name
        set item.ClassName = config.className
        set item.Category = $select($isobject(config)&&(config.category'=""):config.category, 1:"AIGenerated")
        set item.Enabled = $select($isobject(config)&&(config.enabled'=""):config.enabled, 1:1)
        set item.Comment = $select($isobject(config)&&(config.comment'=""):config.comment, 1:"Added by IRIS Copilot")

        // Build settings string from config.settings object
        if $isobject(config.settings) {
            set settingsStr = ""
            set iter = config.settings.%GetIterator()
            while iter.%GetNext(.key, .val) {
                set:settingsStr'="" settingsStr = settingsStr _ ","
                set settingsStr = settingsStr _ key _ "=" _ val
            }
            set item.Settings = settingsStr
        }

        do prodDef.Items.Insert(item)
        set sc = prodDef.%Save()

        if $$$ISOK(sc) {
            do ##class(AIAgent.Model.AuditEntry).LogSuccess("deploy", config.name, "Added to production "_prodName)
            do ##class(AIAgent.Util.Logger).Info("ProductionManager", "Added host", config.name)
        }
    } catch ex {
        set sc = ex.AsStatus()
        do ##class(AIAgent.Model.AuditEntry).LogFailure("deploy", config.name, ex.DisplayString())
    }
    return sc
}

/// Remove a business host from the production by name.
ClassMethod RemoveBusinessHost(itemName As %String) As %Status
{
    set sc = $$$OK
    try {
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
            return $$$ERROR($$$GeneralError, "Host '"_itemName_"' not found in production")
        }
        set sc = prodDef.%Save()

        if $$$ISOK(sc) {
            do ##class(AIAgent.Model.AuditEntry).LogSuccess("delete", itemName, "Removed from production")
            do ##class(AIAgent.Util.Logger).Info("ProductionManager", "Removed host", itemName)
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Update settings for an existing business host.
/// settings is a %DynamicObject of {key: value} pairs.
ClassMethod UpdateHostSettings(itemName As %String, settings As %DynamicObject) As %Status
{
    set sc = $$$OK
    try {
        do ##class(Ens.Director).GetProductionStatus(.prodName, .prodStatus)
        set prodDef = ##class(Ens.Config.Production).%OpenId(prodName)
        if '$isobject(prodDef) {
            return $$$ERROR($$$GeneralError, "Cannot open production")
        }

        set found = 0
        for i = 1:1:prodDef.Items.Count() {
            set item = prodDef.Items.GetAt(i)
            if item.Name = itemName {
                // Build new settings string
                set settingsStr = ""
                set iter = settings.%GetIterator()
                while iter.%GetNext(.key, .val) {
                    set:settingsStr'="" settingsStr = settingsStr _ ","
                    set settingsStr = settingsStr _ key _ "=" _ val
                }
                set item.Settings = settingsStr
                set found = 1
                quit
            }
        }
        if 'found {
            return $$$ERROR($$$GeneralError, "Host '"_itemName_"' not found")
        }
        set sc = prodDef.%Save()
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
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
