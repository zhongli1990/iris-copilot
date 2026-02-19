/// REST API Dispatcher for the IRIS AI Agent Platform (IRIS Copilot).
/// Serves as the single HTTP entry point for all client interactions.
/// Delegates to Engine classes for business logic and uses AIAgent.Util.JSON for response formatting.
/// 
/// Deployed as web application /ai via AIAgent.Install.Installer.
/// 
/// Part of the IRIS AI Agent Platform (IRIS Copilot).
Class AIAgent.API.Dispatcher Extends %CSP.REST
{

Parameter CONTENTTYPE = "application/json";

Parameter CHARSET = "utf-8";

Parameter HandleCorsRequest = 1;

/// URL routing map.
XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
    <!-- Chat -->
    <Route Url="/chat" Method="POST" Call="SendMessage" />
    <Route Url="/chat/stream" Method="POST" Call="SendMessageSSE" />
    <Route Url="/conversations" Method="GET" Call="ListConversations" />
    <Route Url="/conversations" Method="POST" Call="CreateConversation" />
    <Route Url="/conversations/:id" Method="GET" Call="GetConversation" />
    <Route Url="/conversations/:id" Method="DELETE" Call="DeleteConversation" />

    <!-- Code Generation & Review -->
    <Route Url="/generate/preview" Method="POST" Call="PreviewGeneration" />
    <Route Url="/generate/approve" Method="POST" Call="ApproveGeneration" />
    <Route Url="/generate/reject" Method="POST" Call="RejectGeneration" />

    <!-- Production Management -->
    <Route Url="/production/status" Method="GET" Call="GetProductionStatus" />
    <Route Url="/production/topology" Method="GET" Call="GetProductionTopology" />
    <Route Url="/production/start" Method="POST" Call="StartProduction" />
    <Route Url="/production/stop" Method="POST" Call="StopProduction" />
    <Route Url="/production/events" Method="GET" Call="GetEventLog" />
    <Route Url="/production/queues" Method="GET" Call="GetQueueCounts" />

    <!-- Code Management -->
    <Route Url="/classes" Method="GET" Call="ListClasses" />
    <Route Url="/classes/:className" Method="GET" Call="ReadClass" />
    <Route Url="/lookups" Method="GET" Call="ListLookupTables" />
    <Route Url="/lookups/:tableName" Method="GET" Call="ReadLookupTable" />
    <Route Url="/hl7schemas" Method="GET" Call="ListHL7Schemas" />
    <Route Url="/sql" Method="POST" Call="ExecuteSQL" />

    <!-- Lifecycle -->
    <Route Url="/lifecycle/test" Method="POST" Call="RunTests" />
    <Route Url="/lifecycle/rollback/:id" Method="POST" Call="Rollback" />
    <Route Url="/lifecycle/versions" Method="GET" Call="ListVersions" />

    <!-- Runner Management -->
    <Route Url="/runners" Method="GET" Call="ListRunners" />
    <Route Url="/runners/health" Method="GET" Call="RunnerHealthCheck" />
    <Route Url="/capabilities" Method="GET" Call="GetCapabilities" />
    <Route Url="/operate" Method="POST" Call="Operate" />

    <!-- Audit -->
    <Route Url="/audit" Method="GET" Call="GetAuditLog" />

    <!-- System -->
    <Route Url="/health" Method="GET" Call="HealthCheck" />
</Routes>
}

// ---------------------------------------------------------------------------

// CORS Configuration

// ---------------------------------------------------------------------------

/// Handle CORS preflight and response headers.
/// Allows localhost (any port) and *.nhs.uk origins.
ClassMethod OnHandleCorsRequest(url As %String) As %Status
{
    set origin = %request.GetCgiEnv("HTTP_ORIGIN")

    // Allow localhost on any port and any *.nhs.uk subdomain
    set allowed = 0
    if origin [ "://localhost" {
        set allowed = 1
    } elseif origin [ ".nhs.uk" {
        // Validate it ends with .nhs.uk (prevent suffix attacks)
        set host = $piece($piece(origin, "://", 2), "/", 1)
        set host = $piece(host, ":", 1)
        if ($extract(host, *-5, *) = ".nhs.uk") || (host = "nhs.uk") {
            set allowed = 1
        }
    }

    if allowed {
        do %response.SetHeader("Access-Control-Allow-Origin", origin)
    } else {
        do %response.SetHeader("Access-Control-Allow-Origin", "")
    }

    do %response.SetHeader("Access-Control-Allow-Credentials", "true")
    do %response.SetHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
    do %response.SetHeader("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With, Accept")
    do %response.SetHeader("Access-Control-Max-Age", "3600")

    return $$$OK
}

// ---------------------------------------------------------------------------

// Chat Endpoints

// ---------------------------------------------------------------------------

/// POST /chat
/// Send a message within a conversation. Creates a new conversation if conversationId is empty.
/// Body: {"conversationId":"...", "message":"..."}
ClassMethod SendMessage() As %Status
{
    try {
        set body = ##class(AIAgent.Util.JSON).ReadRequestJSON()
        if '$isobject(body) {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INVALID_BODY", "Request body must be valid JSON", 400))
            return $$$OK
        }

        set message = body.%Get("message")
        if message = "" {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("MISSING_FIELD", "'message' is required", 400))
            return $$$OK
        }
        set preferredRunner = body.%Get("preferredRunner")

        set conversationId = body.%Get("conversationId")
        if conversationId = "" {
            // Create a new conversation
            set conv = ##class(AIAgent.Model.Conversation).Create("", $namespace)
            if '$isobject(conv) {
                do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("CREATE_FAILED", "Failed to create conversation", 500))
                return $$$OK
            }
            set conversationId = conv.ConversationId
        }

        set result = ##class(AIAgent.Engine.Orchestrator).ProcessMessage(conversationId, message, preferredRunner)

        if result.error '= "" {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("ORCHESTRATOR_ERROR", result.error, 500))
            return $$$OK
        }

        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(result))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "SendMessage", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// POST /chat/stream
/// Send a message and receive the response as Server-Sent Events (SSE).
/// Body: {"conversationId":"...", "message":"..."}
ClassMethod SendMessageSSE() As %Status
{
    try {
        set body = ##class(AIAgent.Util.JSON).ReadRequestJSON()
        if '$isobject(body) {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INVALID_BODY", "Request body must be valid JSON", 400))
            return $$$OK
        }

        set message = body.%Get("message")
        if message = "" {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("MISSING_FIELD", "'message' is required", 400))
            return $$$OK
        }
        set preferredRunner = body.%Get("preferredRunner")

        set conversationId = body.%Get("conversationId")
        if conversationId = "" {
            set conv = ##class(AIAgent.Model.Conversation).Create("", $namespace)
            if '$isobject(conv) {
                do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("CREATE_FAILED", "Failed to create conversation", 500))
                return $$$OK
            }
            set conversationId = conv.ConversationId
        }

        // Set SSE response headers
        set %response.ContentType = "text/event-stream"
        set %response.CharSet = "utf-8"
        do %response.SetHeader("Cache-Control", "no-cache")
        do %response.SetHeader("Connection", "keep-alive")
        do %response.SetHeader("X-Accel-Buffering", "no")

        // Save the user message first
        set userMsg = ##class(AIAgent.Model.Message).Create(conversationId, "user", message)

        // Send conversationId as first event
        set initData = ##class(%DynamicObject).%New()
        set initData.conversationId = conversationId
        set initData.type = "init"
        write "data: "_initData.%ToJSON(), !!, *-3

        // Stream the response from the bridge
        set sc = ##class(AIAgent.Engine.BridgeClient).SendMessageStream(conversationId, message, .fullResponse, preferredRunner)

        // Reliability fallback: if streaming returned no content, do a non-stream
        // bridge call and emit/persist that response so the user never gets an
        // empty assistant message.
        if $$$ISOK(sc) && (fullResponse = "") {
            set fallback = ##class(AIAgent.Engine.BridgeClient).SendMessage(conversationId, message, $namespace, preferredRunner)
            if $isobject(fallback) && (fallback.%Get("error") = "") {
                set fallbackText = fallback.%Get("response")
                if fallbackText '= "" {
                    set fullResponse = fallbackText
                    set fbData = ##class(%DynamicObject).%New()
                    set fbData.token = fallbackText
                    set fbData.done = 0
                    set fbData.type = "fallback"
                    write "data: "_fbData.%ToJSON(), !!, *-3
                }
            }
        }

        if $$$ISOK(sc) {
            if fullResponse = "" {
                set fullResponse = "(No response content returned by bridge stream)"
            }
            do ##class(AIAgent.Model.Message).Create(conversationId, "assistant", fullResponse)
        }

        // Send done event
        set doneData = ##class(%DynamicObject).%New()
        set doneData.type = "done"
        set doneData.conversationId = conversationId
        write "data: "_doneData.%ToJSON(), !!, *-3

    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "SendMessageSSE", ex.DisplayString())
        set errData = ##class(%DynamicObject).%New()
        set errData.type = "error"
        set errData.message = ex.DisplayString()
        try {
            write "data: "_errData.%ToJSON(), !!, *-3
        } catch {}
    }
    return $$$OK
}

/// GET /conversations
/// List conversations with optional pagination and status filter.
/// Query params: page (default 1), pageSize (default 20), status (optional)
ClassMethod ListConversations() As %Status
{
    try {
        set page = ##class(AIAgent.Util.JSON).GetIntParam("page", 1)
        set pageSize = ##class(AIAgent.Util.JSON).GetIntParam("pageSize", 20)
        set status = ##class(AIAgent.Util.JSON).GetParam("status")

        set result = ##class(AIAgent.Model.Conversation).List(page, pageSize, status)
        do ##class(AIAgent.Util.JSON).WriteJSON(result)
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "ListConversations", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// POST /conversations
/// Create a new conversation.
/// Body: {"title":"...", "targetNamespace":"..."}
ClassMethod CreateConversation() As %Status
{
    try {
        set body = ##class(AIAgent.Util.JSON).ReadRequestJSON()
        set title = ""
        set targetNs = ""
        if $isobject(body) {
            set title = body.%Get("title")
            set targetNs = body.%Get("targetNamespace")
        }

        set conv = ##class(AIAgent.Model.Conversation).Create(title, targetNs)
        if '$isobject(conv) {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("CREATE_FAILED", "Failed to create conversation", 500))
            return $$$OK
        }

        set %response.Status = "201 Created"
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(conv.ToJSON()))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "CreateConversation", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// GET /conversations/:id
/// Get a conversation with its messages.
ClassMethod GetConversation(id As %String) As %Status
{
    try {
        set conv = ##class(AIAgent.Model.Conversation).FindById(id)
        if '$isobject(conv) {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("NOT_FOUND", "Conversation '"_id_"' not found", 404))
            return $$$OK
        }

        set data = conv.ToJSON()
        // Include messages
        set data.messages = ##class(AIAgent.Model.Message).GetByConversation(id)
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(data))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "GetConversation", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// DELETE /conversations/:id
/// Delete (archive) a conversation.
ClassMethod DeleteConversation(id As %String) As %Status
{
    try {
        set conv = ##class(AIAgent.Model.Conversation).FindById(id)
        if '$isobject(conv) {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("NOT_FOUND", "Conversation '"_id_"' not found", 404))
            return $$$OK
        }

        // Soft-delete by archiving
        set conv.Status = "archived"
        set sc = conv.%Save()
        if $$$ISERR(sc) {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).StatusToError(sc))
            return $$$OK
        }

        do ##class(AIAgent.Model.AuditEntry).LogSuccess("delete", "conversation:"_id)
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(conv.ToJSON()))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "DeleteConversation", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

// ---------------------------------------------------------------------------

// Code Generation & Review Endpoints

// ---------------------------------------------------------------------------

/// POST /generate/preview
/// Preview a generation without deploying. Delegates to the Orchestrator.
/// Body: {"conversationId":"...", "message":"..."}
ClassMethod PreviewGeneration() As %Status
{
    try {
        set body = ##class(AIAgent.Util.JSON).ReadRequestJSON()
        if '$isobject(body) {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INVALID_BODY", "Request body must be valid JSON", 400))
            return $$$OK
        }

        set conversationId = body.%Get("conversationId")
        set message = body.%Get("message")
        if message = "" {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("MISSING_FIELD", "'message' is required", 400))
            return $$$OK
        }

        if conversationId = "" {
            set conv = ##class(AIAgent.Model.Conversation).Create("Code Generation", $namespace)
            if '$isobject(conv) {
                do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("CREATE_FAILED", "Failed to create conversation", 500))
                return $$$OK
            }
            set conversationId = conv.ConversationId
        }

        // ProcessMessage will return the generation in preview status
        set result = ##class(AIAgent.Engine.Orchestrator).ProcessMessage(conversationId, message)

        if result.error '= "" {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("GENERATION_ERROR", result.error, 500))
            return $$$OK
        }

        // If a generation was created, include its details
        if result.generationId '= "" {
            set gen = ##class(AIAgent.Model.Generation).FindById(result.generationId)
            if $isobject(gen) {
                set result.generation = gen.ToJSON()
            }
        }

        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(result))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "PreviewGeneration", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// POST /generate/approve
/// Approve a generation and deploy it (compile classes, update production).
/// Body: {"generationId":"..."}
ClassMethod ApproveGeneration() As %Status
{
    try {
        set body = ##class(AIAgent.Util.JSON).ReadRequestJSON()
        if '$isobject(body) {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INVALID_BODY", "Request body must be valid JSON", 400))
            return $$$OK
        }

        set generationId = body.%Get("generationId")
        if generationId = "" {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("MISSING_FIELD", "'generationId' is required", 400))
            return $$$OK
        }

        set result = ##class(AIAgent.Engine.Orchestrator).ApproveAndDeploy(generationId)

        if result.error '= "" {
            set httpStatus = $select(result.error [ "not found":404, result.error [ "expected":409, 1:500)
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("APPROVAL_ERROR", result.error, httpStatus))
            return $$$OK
        }

        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(result))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "ApproveGeneration", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// POST /generate/reject
/// Reject a generation (do not deploy).
/// Body: {"generationId":"...", "reason":"..."}
ClassMethod RejectGeneration() As %Status
{
    try {
        set body = ##class(AIAgent.Util.JSON).ReadRequestJSON()
        if '$isobject(body) {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INVALID_BODY", "Request body must be valid JSON", 400))
            return $$$OK
        }

        set generationId = body.%Get("generationId")
        if generationId = "" {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("MISSING_FIELD", "'generationId' is required", 400))
            return $$$OK
        }

        set reason = body.%Get("reason")
        set sc = ##class(AIAgent.Engine.Orchestrator).RejectGeneration(generationId, reason)

        if $$$ISERR(sc) {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).StatusToError(sc, 404))
            return $$$OK
        }

        set data = ##class(%DynamicObject).%New()
        set data.generationId = generationId
        set data.status = "rejected"
        set data.reason = reason
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(data))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "RejectGeneration", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

// ---------------------------------------------------------------------------

// Production Management Endpoints

// ---------------------------------------------------------------------------

/// GET /production/status
/// Get current production name, status, and namespace.
ClassMethod GetProductionStatus() As %Status
{
    try {
        set data = ##class(AIAgent.Engine.ProductionManager).GetStatus()
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(data))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "GetProductionStatus", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// GET /production/topology
/// Get full production topology: all business hosts with their configurations.
ClassMethod GetProductionTopology() As %Status
{
    try {
        set data = ##class(AIAgent.Engine.ProductionManager).GetTopology()
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(data))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "GetProductionTopology", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// POST /production/start
/// Start the production.
/// Body (optional): {"productionName":"..."}
ClassMethod StartProduction() As %Status
{
    try {
        set body = ##class(AIAgent.Util.JSON).ReadRequestJSON()
        set productionName = ""
        if $isobject(body) {
            set productionName = body.%Get("productionName")
        }

        set sc = ##class(AIAgent.Engine.ProductionManager).StartProduction(productionName)

        if $$$ISERR(sc) {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).StatusToError(sc))
            return $$$OK
        }

        // Return fresh status after starting
        set data = ##class(AIAgent.Engine.ProductionManager).GetStatus()
        set data.action = "started"
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(data))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "StartProduction", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// POST /production/stop
/// Stop the production.
/// Body (optional): {"timeout": 300}
ClassMethod StopProduction() As %Status
{
    try {
        set body = ##class(AIAgent.Util.JSON).ReadRequestJSON()
        set timeout = 300
        if $isobject(body) && (body.%Get("timeout") '= "") {
            set timeout = +body.%Get("timeout")
        }

        set sc = ##class(AIAgent.Engine.ProductionManager).StopProduction(timeout)

        if $$$ISERR(sc) {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).StatusToError(sc))
            return $$$OK
        }

        set data = ##class(AIAgent.Engine.ProductionManager).GetStatus()
        set data.action = "stopped"
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(data))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "StopProduction", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// GET /production/events
/// Get recent event log entries.
/// Query params: count (default 50), configName (optional)
ClassMethod GetEventLog() As %Status
{
    try {
        set count = ##class(AIAgent.Util.JSON).GetIntParam("count", 50)
        set configName = ##class(AIAgent.Util.JSON).GetParam("configName")

        set data = ##class(AIAgent.Engine.ProductionManager).GetEventLog(count, configName)
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(data))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "GetEventLog", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// GET /production/queues
/// Get message queue depths for all hosts.
ClassMethod GetQueueCounts() As %Status
{
    try {
        set data = ##class(AIAgent.Engine.ProductionManager).GetQueueCounts()
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(data))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "GetQueueCounts", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

// ---------------------------------------------------------------------------

// Code Management Endpoints

// ---------------------------------------------------------------------------

/// GET /classes
/// List classes matching a pattern.
/// Query params: pattern (default "AIAgent.Generated.%")
ClassMethod ListClasses() As %Status
{
    try {
        set pattern = ##class(AIAgent.Util.JSON).GetParam("pattern", "AIAgent.Generated.%")

        set data = ##class(AIAgent.Engine.CodeManager).ListClasses(pattern)
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(data))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "ListClasses", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// GET /classes/:className
/// Read the full source of a class.
ClassMethod ReadClass(className As %String) As %Status
{
    try {
        // URL-decode the class name (dots may be encoded as %2E)
        set className = $zconvert(className, "I", "URL")

        if '##class(AIAgent.Engine.CodeManager).ClassExists(className) {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("NOT_FOUND", "Class '"_className_"' not found", 404))
            return $$$OK
        }

        set sc = ##class(AIAgent.Engine.CodeManager).ReadClass(className, .source)
        if $$$ISERR(sc) {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).StatusToError(sc))
            return $$$OK
        }

        set data = ##class(%DynamicObject).%New()
        set data.className = className
        set data.source = source
        set data.exists = 1
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(data))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "ReadClass", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// GET /lookups
/// List all lookup tables and their entry counts.
ClassMethod ListLookupTables() As %Status
{
    try {
        set data = ##class(AIAgent.Engine.CodeManager).ListLookupTables()
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(data))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "ListLookupTables", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// GET /lookups/:tableName
/// Read entries from a specific lookup table.
ClassMethod ReadLookupTable(tableName As %String) As %Status
{
    try {
        set tableName = $zconvert(tableName, "I", "URL")

        set data = ##class(AIAgent.Engine.CodeManager).ReadLookupTable(tableName)
        set result = ##class(%DynamicObject).%New()
        set result.tableName = tableName
        set result.entries = data
        set result.entryCount = data.%Size()
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(result))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "ReadLookupTable", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// GET /hl7schemas
/// List all HL7 schemas (standard and custom).
ClassMethod ListHL7Schemas() As %Status
{
    try {
        set data = ##class(AIAgent.Engine.CodeManager).ListHL7Schemas()
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(data))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "ListHL7Schemas", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// POST /sql
/// Execute a read-only SQL query and return results.
/// Body: {"query":"SELECT ..."}
ClassMethod ExecuteSQL() As %Status
{
    try {
        set body = ##class(AIAgent.Util.JSON).ReadRequestJSON()
        if '$isobject(body) {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INVALID_BODY", "Request body must be valid JSON", 400))
            return $$$OK
        }

        set query = body.%Get("query")
        if query = "" {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("MISSING_FIELD", "'query' is required", 400))
            return $$$OK
        }

        set result = ##class(AIAgent.Engine.CodeManager).ExecuteSQL(query)

        if result.error '= "" {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("SQL_ERROR", result.error, 400))
            return $$$OK
        }

        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(result))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "ExecuteSQL", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

// ---------------------------------------------------------------------------

// Lifecycle Endpoints

// ---------------------------------------------------------------------------

/// POST /lifecycle/test
/// Run unit tests for a class or pattern.
/// Body: {"testClass":"...", "pattern":"..."}
/// If testClass is provided, runs a single test class.
/// If pattern is provided, runs all matching test classes.
ClassMethod RunTests() As %Status
{
    try {
        set body = ##class(AIAgent.Util.JSON).ReadRequestJSON()
        if '$isobject(body) {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INVALID_BODY", "Request body must be valid JSON", 400))
            return $$$OK
        }

        set testClass = body.%Get("testClass")
        set pattern = body.%Get("pattern")

        if (testClass = "") && (pattern = "") {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("MISSING_FIELD", "'testClass' or 'pattern' is required", 400))
            return $$$OK
        }

        if testClass '= "" {
            // Run a single test class
            set result = ##class(AIAgent.Engine.TestRunner).RunTestClass(testClass)
        } else {
            // Run a test suite matching the pattern
            set result = ##class(AIAgent.Engine.TestRunner).RunTestSuite(pattern)
        }

        if result.error '= "" {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("TEST_ERROR", result.error, 400))
            return $$$OK
        }

        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(result))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "RunTests", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// POST /lifecycle/rollback/:id
/// Rollback to a specific version snapshot.
ClassMethod Rollback(id As %String) As %Status
{
    try {
        set id = $zconvert(id, "I", "URL")

        set sc = ##class(AIAgent.Engine.VersionManager).Rollback(id, .log)

        if $$$ISERR(sc) {
            set errMsg = $system.Status.GetOneErrorText(sc)
            set httpStatus = $select(errMsg [ "not found":404, errMsg [ "empty":400, 1:500)
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("ROLLBACK_ERROR", errMsg, httpStatus))
            return $$$OK
        }

        set data = ##class(%DynamicObject).%New()
        set data.versionId = id
        set data.status = "rolled_back"
        set data.log = log
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(data))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "Rollback", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// GET /lifecycle/versions
/// List version snapshots.
/// Query params: page (default 1), pageSize (default 20)
ClassMethod ListVersions() As %Status
{
    try {
        set page = ##class(AIAgent.Util.JSON).GetIntParam("page", 1)
        set pageSize = ##class(AIAgent.Util.JSON).GetIntParam("pageSize", 20)

        set data = ##class(AIAgent.Engine.VersionManager).ListVersions(page, pageSize)
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(data))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "ListVersions", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

// ---------------------------------------------------------------------------

// Runner Management Endpoints

// ---------------------------------------------------------------------------

/// GET /runners
/// List available AI runners from the bridge.
ClassMethod ListRunners() As %Status
{
    try {
        set data = ##class(AIAgent.Engine.BridgeClient).ListRunners()
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(data))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "ListRunners", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// GET /runners/health
/// Check connectivity and health of the AI runner bridge.
ClassMethod RunnerHealthCheck() As %Status
{
    try {
        set data = ##class(AIAgent.Engine.BridgeClient).HealthCheck()
        if 'data.healthy {
            set %response.Status = "503 Service Unavailable"
        }
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(data))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "RunnerHealthCheck", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// GET /capabilities
/// Return effective generic capabilities for the current user and namespace.
/// Query params: namespace (optional, defaults to current)
ClassMethod GetCapabilities() As %Status
{
    try {
        set ns = ##class(AIAgent.Util.JSON).GetParam("namespace", $namespace)
        set data = ..BuildCapabilities(ns)
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(data))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "GetCapabilities", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// POST /operate
/// Generic operation gateway (additive path).
/// Body: {"namespace":"...","op":"discover|query|mutate|execute|govern","target":"...","action":"...","args":{},"dryRun":true|false}
ClassMethod Operate() As %Status
{
    try {
        set body = ##class(AIAgent.Util.JSON).ReadRequestJSON()
        if '$isobject(body) {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INVALID_BODY", "Request body must be valid JSON", 400))
            return $$$OK
        }

        set op = body.%Get("op")
        set target = body.%Get("target")
        if (op = "") || (target = "") {
            do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("MISSING_FIELD", "'op' and 'target' are required", 400))
            return $$$OK
        }

        set ns = body.%Get("namespace")
        if ns = "" set ns = $namespace
        set action = body.%Get("action")
        set dryRun = +body.%Get("dryRun")
        set args = body.%Get("args")
        if '$isobject(args) {
            set args = ##class(%DynamicObject).%New()
        }

        set result = ##class(%DynamicObject).%New()
        set meta = ##class(%DynamicObject).%New()
        set meta.namespace = ns
        set meta.executedBy = $username
        set meta.requiresApproval = 0

        if op = "discover" {
            if target = "capabilities" {
                set result.data = ..BuildCapabilities(ns)
                set meta.capability = "discover.capabilities"
            } elseif target = "namespaces" {
                set arr = ##class(%DynamicArray).%New()
                do arr.%Push($namespace)
                set result.data = arr
                set meta.capability = "discover.namespaces"
            } elseif target = "targets" {
                set result.data = ..BuildTargetCatalog()
                set meta.capability = "discover.targets"
            } else {
                do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("UNSUPPORTED_TARGET", "Unsupported discover target: "_target, 400))
                return $$$OK
            }
        } elseif op = "query" {
            if target = "production/status" {
                set result.data = ##class(AIAgent.Engine.ProductionManager).GetStatus()
                set meta.capability = "production.status.read"
            } elseif target = "production/topology" {
                set result.data = ##class(AIAgent.Engine.ProductionManager).GetTopology()
                set meta.capability = "production.topology.read"
            } elseif target = "production/events" {
                set count = args.%Get("count")
                if count = "" set count = 50
                set cfg = args.%Get("configName")
                set result.data = ##class(AIAgent.Engine.ProductionManager).GetEventLog(count, cfg)
                set meta.capability = "production.events.read"
            } elseif target = "production/queues" {
                set result.data = ##class(AIAgent.Engine.ProductionManager).GetQueueCounts()
                set meta.capability = "production.queues.read"
            } elseif target = "lookups" {
                set result.data = ##class(AIAgent.Engine.CodeManager).ListLookupTables()
                set meta.capability = "lookup.catalog.read"
            } elseif target = "hl7schemas" {
                set result.data = ##class(AIAgent.Engine.CodeManager).ListHL7Schemas()
                set meta.capability = "hl7schemas.read"
            } elseif $extract(target,1,7) = "lookup/" {
                set tableName = $extract(target,8,*)
                set entries = ##class(AIAgent.Engine.CodeManager).ReadLookupTable(tableName)
                set obj = ##class(%DynamicObject).%New()
                set obj.tableName = tableName
                set obj.entries = entries
                set obj.entryCount = entries.%Size()
                set result.data = obj
                set meta.capability = "lookup.read"
            } elseif target = "classes" {
                set pattern = args.%Get("pattern")
                if pattern = "" set pattern = "AIAgent.Generated.%"
                set result.data = ##class(AIAgent.Engine.CodeManager).ListClasses(pattern)
                set meta.capability = "class.catalog.read"
            } elseif $extract(target,1,6) = "class/" {
                set className = $extract(target,7,*)
                if '##class(AIAgent.Engine.CodeManager).ClassExists(className) {
                    do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("NOT_FOUND", "Class '"_className_"' not found", 404))
                    return $$$OK
                }
                set sc = ##class(AIAgent.Engine.CodeManager).ReadClass(className, .source)
                if $$$ISERR(sc) {
                    do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).StatusToError(sc))
                    return $$$OK
                }
                set obj = ##class(%DynamicObject).%New()
                set obj.className = className
                set obj.source = source
                set result.data = obj
                set meta.capability = "class.read"
            } elseif target = "lifecycle/versions" {
                set page = args.%Get("page")
                if page = "" set page = 1
                set pageSize = args.%Get("pageSize")
                if pageSize = "" set pageSize = 20
                set result.data = ##class(AIAgent.Engine.VersionManager).ListVersions(page, pageSize)
                set meta.capability = "lifecycle.versions.read"
            } elseif target = "sql/select" {
                set query = args.%Get("query")
                if query = "" set query = args.%Get("sql")
                set queryTrim = $zstrip(query, "<W")
                if queryTrim = "" {
                    do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("MISSING_FIELD", "'args.query' is required for target sql/select", 400))
                    return $$$OK
                }
                set low = $zconvert(queryTrim, "L")
                if $extract(low,1,6) '= "select" {
                    do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INVALID_QUERY", "Only SELECT queries are allowed for target sql/select", 400))
                    return $$$OK
                }
                set sqlResult = ##class(AIAgent.Engine.CodeManager).ExecuteSQL(queryTrim)
                if sqlResult.error '= "" {
                    do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("SQL_ERROR", sqlResult.error, 400))
                    return $$$OK
                }
                set result.data = sqlResult
                set meta.capability = "sql.read"
            } else {
                do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("UNSUPPORTED_TARGET", "Unsupported query target: "_target, 400))
                return $$$OK
            }
        } elseif op = "execute" {
            set meta.requiresApproval = 1
            if dryRun {
                set plan = ##class(%DynamicObject).%New()
                set plan.status = "dry_run"
                set plan.target = target
                set plan.message = "Execution was not applied because dryRun=true"
                set result.data = plan
                set meta.capability = "execute.plan"
            } elseif target = "generation/approve" {
                set generationId = args.%Get("generationId")
                if generationId = "" {
                    do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("MISSING_FIELD", "'args.generationId' is required for target generation/approve", 400))
                    return $$$OK
                }
                set result.data = ##class(AIAgent.Engine.Orchestrator).ApproveAndDeploy(generationId)
                set meta.capability = "execute.generation.approve"
            } elseif target = "generation/reject" {
                set generationId = args.%Get("generationId")
                if generationId = "" {
                    do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("MISSING_FIELD", "'args.generationId' is required for target generation/reject", 400))
                    return $$$OK
                }
                set reason = args.%Get("reason")
                set sc = ##class(AIAgent.Engine.Orchestrator).RejectGeneration(generationId, reason)
                if $$$ISERR(sc) {
                    do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).StatusToError(sc))
                    return $$$OK
                }
                set obj = ##class(%DynamicObject).%New()
                set obj.generationId = generationId
                set obj.status = "rejected"
                set obj.reason = reason
                set result.data = obj
                set meta.capability = "execute.generation.reject"
            } elseif target = "production/start" {
                set productionName = args.%Get("productionName")
                set sc = ##class(AIAgent.Engine.ProductionManager).StartProduction(productionName)
                if $$$ISERR(sc) {
                    do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).StatusToError(sc))
                    return $$$OK
                }
                set result.data = ##class(AIAgent.Engine.ProductionManager).GetStatus()
                set meta.capability = "execute.production.start"
            } elseif target = "production/stop" {
                set timeout = args.%Get("timeout")
                if timeout = "" set timeout = 300
                set sc = ##class(AIAgent.Engine.ProductionManager).StopProduction(timeout)
                if $$$ISERR(sc) {
                    do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).StatusToError(sc))
                    return $$$OK
                }
                set result.data = ##class(AIAgent.Engine.ProductionManager).GetStatus()
                set meta.capability = "execute.production.stop"
            } elseif target = "lifecycle/rollback" {
                set versionId = args.%Get("versionId")
                if versionId = "" set versionId = args.%Get("id")
                if versionId = "" {
                    do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("MISSING_FIELD", "'args.versionId' is required for target lifecycle/rollback", 400))
                    return $$$OK
                }
                set sc = ##class(AIAgent.Engine.VersionManager).Rollback(versionId, .rollbackLog)
                if $$$ISERR(sc) {
                    do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).StatusToError(sc))
                    return $$$OK
                }
                set obj = ##class(%DynamicObject).%New()
                set obj.versionId = versionId
                set obj.status = "rolled_back"
                set obj.log = rollbackLog
                set result.data = obj
                set meta.capability = "execute.lifecycle.rollback"
            } else {
                do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("UNSUPPORTED_TARGET", "Unsupported execute target: "_target, 400))
                return $$$OK
            }
        } elseif op = "mutate" {
            set meta.requiresApproval = 1
            if dryRun {
                set plan = ##class(%DynamicObject).%New()
                set plan.status = "dry_run"
                set plan.target = target
                set plan.message = "Mutation was not applied because dryRun=true"
                set result.data = plan
                set meta.capability = "mutate.plan"
            } elseif target = "production/host/add" {
                set hostConfig = args.%Get("config")
                if '$isobject(hostConfig) set hostConfig = args
                set sc = ##class(AIAgent.Engine.ProductionManager).AddBusinessHost(hostConfig)
                if $$$ISERR(sc) {
                    do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).StatusToError(sc))
                    return $$$OK
                }
                set result.data = ##class(AIAgent.Engine.ProductionManager).GetTopology()
                set meta.capability = "mutate.production.host.add"
            } elseif target = "production/host/remove" {
                set hostName = args.%Get("name")
                if hostName = "" set hostName = args.%Get("itemName")
                if hostName = "" {
                    do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("MISSING_FIELD", "'args.name' is required for target production/host/remove", 400))
                    return $$$OK
                }
                set sc = ##class(AIAgent.Engine.ProductionManager).RemoveBusinessHost(hostName)
                if $$$ISERR(sc) {
                    do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).StatusToError(sc))
                    return $$$OK
                }
                set result.data = ##class(AIAgent.Engine.ProductionManager).GetTopology()
                set meta.capability = "mutate.production.host.remove"
            } elseif target = "production/host/settings" {
                set hostName = args.%Get("name")
                if hostName = "" set hostName = args.%Get("itemName")
                set settings = args.%Get("settings")
                if (hostName = "") || ('$isobject(settings)) {
                    do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("MISSING_FIELD", "'args.name' and object 'args.settings' are required for target production/host/settings", 400))
                    return $$$OK
                }
                set sc = ##class(AIAgent.Engine.ProductionManager).UpdateHostSettings(hostName, settings)
                if $$$ISERR(sc) {
                    do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).StatusToError(sc))
                    return $$$OK
                }
                set result.data = ##class(AIAgent.Engine.ProductionManager).GetTopology()
                set meta.capability = "mutate.production.host.settings"
            } else {
                do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("UNSUPPORTED_TARGET", "Unsupported mutate target: "_target, 400))
                return $$$OK
            }
        } else {
            set meta.requiresApproval = 1
            set result.data = ##class(%DynamicObject).%New()
            set result.data.status = "pending_implementation"
            set result.data.message = "Operation '"_op_"' is recognized but not yet enabled in generic gateway."
            set meta.capability = op_".pending"
        }

        set result.meta = meta
        set result.dryRun = dryRun
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(result))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "Operate", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

/// Build effective capabilities for current user/session.
ClassMethod BuildCapabilities(ns As %String = "") As %DynamicObject [ Private ]
{
    set data = ##class(%DynamicObject).%New()
    if ns = "" set ns = $namespace
    set data.namespace = ns
    set data.username = $username
    set data.ensembleAvailable = ##class(%Dictionary.CompiledClass).%ExistsId("Ens.Director")
    set caps = ##class(%DynamicArray).%New()

    // Discover + query capabilities (read-first phase)
    do caps.%Push(..Cap("discover.capabilities", ns, 1))
    do caps.%Push(..Cap("discover.namespaces", ns, 1))
    do caps.%Push(..Cap("discover.targets", ns, 1))
    do caps.%Push(..Cap("production.status.read", ns, data.ensembleAvailable))
    do caps.%Push(..Cap("production.topology.read", ns, data.ensembleAvailable))
    do caps.%Push(..Cap("production.events.read", ns, data.ensembleAvailable))
    do caps.%Push(..Cap("production.queues.read", ns, data.ensembleAvailable))
    do caps.%Push(..Cap("lookup.catalog.read", ns, 1))
    do caps.%Push(..Cap("lookup.read", ns, 1))
    do caps.%Push(..Cap("hl7schemas.read", ns, 1))
    do caps.%Push(..Cap("class.catalog.read", ns, 1))
    do caps.%Push(..Cap("class.read", ns, 1))
    do caps.%Push(..Cap("sql.read", ns, 1))
    do caps.%Push(..Cap("lifecycle.versions.read", ns, 1))

    // Generic execute/mutate capabilities (approval-gated)
    do caps.%Push(..Cap("execute.generation.approve", ns, 1, "approval_required"))
    do caps.%Push(..Cap("execute.generation.reject", ns, 1, "approval_required"))
    do caps.%Push(..Cap("execute.production.start", ns, data.ensembleAvailable, "approval_required"))
    do caps.%Push(..Cap("execute.production.stop", ns, data.ensembleAvailable, "approval_required"))
    do caps.%Push(..Cap("execute.lifecycle.rollback", ns, 1, "approval_required"))
    do caps.%Push(..Cap("mutate.production.host.add", ns, data.ensembleAvailable, "approval_required"))
    do caps.%Push(..Cap("mutate.production.host.remove", ns, data.ensembleAvailable, "approval_required"))
    do caps.%Push(..Cap("mutate.production.host.settings", ns, data.ensembleAvailable, "approval_required"))
    do caps.%Push(..Cap("govern.*", ns, 0, "pending_approval_pipeline"))

    set data.capabilities = caps
    return data
}

ClassMethod Cap(capability As %String, ns As %String, allowed As %Integer = 1, reason As %String = "") As %DynamicObject [ Private ]
{
    set obj = ##class(%DynamicObject).%New()
    set obj.capability = capability
    set obj.namespace = ns
    set obj.allowed = allowed
    if reason '= "" set obj.reason = reason
    return obj
}

ClassMethod BuildTargetCatalog() As %DynamicArray [ Private ]
{
    set arr = ##class(%DynamicArray).%New()
    do arr.%Push("discover/capabilities")
    do arr.%Push("discover/namespaces")
    do arr.%Push("discover/targets")
    do arr.%Push("query/production/status")
    do arr.%Push("query/production/topology")
    do arr.%Push("query/production/events")
    do arr.%Push("query/production/queues")
    do arr.%Push("query/lookups")
    do arr.%Push("query/lookup/<TableName>")
    do arr.%Push("query/hl7schemas")
    do arr.%Push("query/classes")
    do arr.%Push("query/class/<ClassName>")
    do arr.%Push("query/lifecycle/versions")
    do arr.%Push("query/sql/select")
    do arr.%Push("mutate/production/host/add (approval-gated)")
    do arr.%Push("mutate/production/host/remove (approval-gated)")
    do arr.%Push("mutate/production/host/settings (approval-gated)")
    do arr.%Push("execute/generation/approve (approval-gated)")
    do arr.%Push("execute/generation/reject (approval-gated)")
    do arr.%Push("execute/production/start (approval-gated)")
    do arr.%Push("execute/production/stop (approval-gated)")
    do arr.%Push("execute/lifecycle/rollback (approval-gated)")
    do arr.%Push("govern/* (approval-gated; pending rollout)")
    return arr
}

// ---------------------------------------------------------------------------

// Audit Endpoints

// ---------------------------------------------------------------------------

/// GET /audit
/// Get audit log entries with optional filters.
/// Query params: action, actor, page (default 1), pageSize (default 50)
ClassMethod GetAuditLog() As %Status
{
    try {
        set action = ##class(AIAgent.Util.JSON).GetParam("action")
        set actor = ##class(AIAgent.Util.JSON).GetParam("actor")
        set page = ##class(AIAgent.Util.JSON).GetIntParam("page", 1)
        set pageSize = ##class(AIAgent.Util.JSON).GetIntParam("pageSize", 50)

        set data = ##class(AIAgent.Model.AuditEntry).Query(action, actor, page, pageSize)
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(data))
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("Dispatcher", "GetAuditLog", ex.DisplayString())
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("INTERNAL_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

// ---------------------------------------------------------------------------

// System Endpoints

// ---------------------------------------------------------------------------

/// GET /health
/// Health check endpoint. Returns platform version, IRIS version, namespace, and uptime info.
ClassMethod HealthCheck() As %Status
{
    try {
        set data = ##class(%DynamicObject).%New()
        set data.status = "healthy"
        set data.platform = "IRIS AI Agent Platform"
        set data.version = "1.0.0"
        set data.irisVersion = $system.Version.GetNumber()
        set data.irisProduct = $system.Version.GetProduct()
        set data.namespace = $namespace
        set data.timestamp = ##class(AIAgent.Util.JSON).Now()
        set data.username = $username

        // Check if Ensemble/HealthConnect is available
        set data.ensembleAvailable = ##class(%Dictionary.CompiledClass).%ExistsId("Ens.Director")

        // Check bridge connectivity
        set bridgeHealth = ##class(AIAgent.Engine.BridgeClient).HealthCheck()
        set data.bridgeHealthy = bridgeHealth.healthy
        set data.bridgeUrl = ##class(AIAgent.Engine.BridgeClient).GetBridgeURL()

        // Production status (only if Ensemble is available)
        if data.ensembleAvailable {
            set prodStatus = ##class(AIAgent.Engine.ProductionManager).GetStatus()
            set data.productionName = prodStatus.productionName
            set data.productionStatus = prodStatus.statusText
        }

        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).SuccessResponse(data))
    } catch ex {
        // Even health check errors should return a structured response
        do ##class(AIAgent.Util.JSON).WriteJSON(##class(AIAgent.Util.JSON).ErrorResponse("HEALTH_ERROR", ex.DisplayString(), 500))
    }
    return $$$OK
}

}
