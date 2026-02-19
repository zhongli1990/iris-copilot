/// Core engine: HTTP client connecting IRIS to the Node.js AI Agent Bridge.
/// All AI interactions flow through this client.
/// 
/// Part of the IRIS AI Agent Platform (IRIS Copilot).
Class AIAgent.Engine.BridgeClient [ Abstract ]
{

/// Base URL of the Node.js AI Agent Bridge.
/// Override via Config.GenericConfig if needed.
Parameter BRIDGEURL = "http://localhost:3100";

/// Request timeout in seconds.
Parameter TIMEOUT = 120;

/// Get the configured bridge URL (checks Config first, falls back to parameter).
ClassMethod GetBridgeURL() As %String
{
    try {
        set configUrl = ##class(Ens.Config.DefaultSettings).GetValue("AIAgent", "BridgeURL")
        if configUrl '= "" return configUrl
    } catch {}
    return ..#BRIDGEURL
}

/// Send a chat message to the bridge and get the full response.
/// Returns a %DynamicObject with the AI response.
ClassMethod SendMessage(conversationId As %String, message As %String, targetNamespace As %String = "", preferredRunner As %String = "") As %DynamicObject
{
    set result = ##class(%DynamicObject).%New()
    try {
        set req = ..CreateRequest("/api/chat")
        // Build JSON body
        set body = ##class(%DynamicObject).%New()
        set body.conversationId = conversationId
        set body.message = message
        set body.namespace = $select(targetNamespace'="":targetNamespace, 1:$namespace)
        if preferredRunner '= "" { set body.preferredRunner = preferredRunner }
        // Add context: production status for the orchestrator
        set body.productionStatus = ##class(AIAgent.Engine.ProductionManager).GetStatus()

        do req.EntityBody.Write(body.%ToJSON())
        set sc = req.Post("/api/chat")
        if $$$ISERR(sc) {
            set result.error = "Bridge connection failed: "_$system.Status.GetOneErrorText(sc)
            return result
        }

        if req.HttpResponse.StatusCode '= 200 {
            set result.error = "Bridge returned HTTP "_req.HttpResponse.StatusCode
            set result.detail = req.HttpResponse.Data.Read()
            return result
        }

        // Parse response
        set responseBody = req.HttpResponse.Data.Read()
        set result = ##class(%DynamicObject).%FromJSON(responseBody)
    } catch ex {
        set result.error = "Bridge client error: "_ex.DisplayString()
        do ##class(AIAgent.Util.Logger).Error("BridgeClient", "SendMessage failed", ex.DisplayString())
    }
    return result
}

/// Send a chat message and stream the response via a callback.
/// The callback method receives each token chunk.
/// Returns a status and the full accumulated response.
ClassMethod SendMessageStream(conversationId As %String, message As %String, Output fullResponse As %String, preferredRunner As %String = "") As %Status
{
    set fullResponse = ""
    set sc = $$$OK
    try {
        set req = ..CreateRequest("/api/chat/stream")
        set body = ##class(%DynamicObject).%New()
        set body.conversationId = conversationId
        set body.message = message
        set body.namespace = $namespace
        if preferredRunner '= "" { set body.preferredRunner = preferredRunner }
        set body.productionStatus = ##class(AIAgent.Engine.ProductionManager).GetStatus()

        do req.EntityBody.Write(body.%ToJSON())
        set sc = req.Post("/api/chat/stream")
        if $$$ISERR(sc) return sc
        if req.HttpResponse.StatusCode '= 200 {
            do ##class(AIAgent.Util.Logger).Error("BridgeClient", "SendMessageStream HTTP error", "HTTP "_req.HttpResponse.StatusCode_": "_req.HttpResponse.Data.Read())
            return $$$ERROR($$$GeneralError, "Bridge returned HTTP "_req.HttpResponse.StatusCode)
        }

        // Read SSE stream
        set stream = req.HttpResponse.Data
        while 'stream.AtEnd {
            set line = stream.ReadLine()
            // SSE format: "data: {...}\n"
            if $extract(line, 1, 6) = "data: " {
                // Always proxy raw SSE data line to the caller first.
                // This keeps UI streaming working even if local JSON parse fails.
                write line, !!, *-3
                set jsonStr = $zstrip($extract(line, 7, *), "<W")
                try {
                    set chunk = ##class(%DynamicObject).%FromJSON(jsonStr)
                    // IRIS 2022.1-safe extraction: rely on %Get default behavior,
                    // avoid %IsDefined checks that can be version-sensitive.
                    set tok = chunk.%Get("token")
                    if tok '= "" {
                        set fullResponse = fullResponse _ tok
                    }
                    set rsp = chunk.%Get("response")
                    if (rsp '= "") && (fullResponse = "") {
                        set fullResponse = rsp
                    }
                    set fr = chunk.%Get("finalResponse")
                    if fr '= "" {
                        // Authoritative fallback emitted by bridge route:
                        // use this value to guarantee persistence when token
                        // parsing is lossy in older IRIS JSON handling.
                        set fullResponse = fr
                    }
                } catch {
                    // Fallback: when JSON parse fails, attempt to recover token text.
                    set tokenRaw = $piece($piece(jsonStr, """token"":""", 2), """,""done""", 1)
                    if tokenRaw '= "" {
                        set wrapper = "{""t"":"""_tokenRaw_"""}"
                        try {
                            set decoded = ##class(%DynamicObject).%FromJSON(wrapper)
                            set tok2 = decoded.%Get("t")
                            if tok2 '= "" {
                                set fullResponse = fullResponse _ tok2
                            }
                        } catch {}
                    }
                }
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
        do ##class(AIAgent.Util.Logger).Error("BridgeClient", "SendMessageStream failed", ex.DisplayString())
    }
    return sc
}

/// Check if the bridge is healthy.
ClassMethod HealthCheck() As %DynamicObject
{
    set result = ##class(%DynamicObject).%New()
    try {
        set req = ..CreateRequest("/api/health")
        set sc = req.Get("/api/health")
        if $$$ISERR(sc) {
            set result.healthy = 0
            set result.error = $system.Status.GetOneErrorText(sc)
            return result
        }
        if req.HttpResponse.StatusCode = 200 {
            set responseBody = req.HttpResponse.Data.Read()
            set result = ##class(%DynamicObject).%FromJSON(responseBody)
            set result.healthy = 1
        } else {
            set result.healthy = 0
            set result.error = "HTTP "_req.HttpResponse.StatusCode
        }
    } catch ex {
        set result.healthy = 0
        set result.error = ex.DisplayString()
    }
    return result
}

/// Get the list of available AI runners from the bridge.
ClassMethod ListRunners() As %DynamicArray
{
    try {
        set req = ..CreateRequest("/api/runners")
        set sc = req.Get("/api/runners")
        if $$$ISOK(sc) && (req.HttpResponse.StatusCode = 200) {
            set responseBody = req.HttpResponse.Data.Read()
            return ##class(%DynamicArray).%FromJSON(responseBody)
        }
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("BridgeClient", "ListRunners failed", ex.DisplayString())
    }
    return ##class(%DynamicArray).%New()
}

/// Internal: create a configured HTTP request to the bridge.
ClassMethod CreateRequest(path As %String) As %Net.HttpRequest [ Private ]
{
    set baseUrl = ..GetBridgeURL()
    set req = ##class(%Net.HttpRequest).%New()

    // Parse URL components
    set host = $piece($piece(baseUrl, "//", 2), ":", 1)
    set port = $piece($piece(baseUrl, "//", 2), ":", 2)
    set:port="" port = $select(baseUrl["https":443, 1:80)
    set:port["/" port = $piece(port, "/", 1)

    set req.Server = host
    set req.Port = port
    set req.Timeout = ..#TIMEOUT
    set req.ContentType = "application/json"
    if baseUrl [ "https" {
        set req.Https = 1
    }

    return req
}

}
