/// Core engine: High-level workflow orchestrator.
/// Coordinates the full lifecycle: message → AI → generate → review → deploy → test.
/// Acts as the main entry point called by the REST API Dispatcher.
/// 
/// Part of the IRIS AI Agent Platform (IRIS Copilot).
Class AIAgent.Engine.Orchestrator [ Abstract ]
{

/// Process a user message within a conversation.
/// This is the main entry point for the chat workflow.
/// Returns a %DynamicObject with the AI response and any generated code.
ClassMethod ProcessMessage(conversationId As %String, userMessage As %String, preferredRunner As %String = "") As %DynamicObject
{
    set result = ##class(%DynamicObject).%New()
    try {
        // 1. Ensure conversation exists
        set conv = ##class(AIAgent.Model.Conversation).FindById(conversationId)
        if '$isobject(conv) {
            set conv = ##class(AIAgent.Model.Conversation).Create("New Conversation", $namespace)
            if '$isobject(conv) {
                set result.error = "Failed to create conversation"
                return result
            }
            set conversationId = conv.ConversationId
        }

        // 2. Save the user message
        set userMsg = ##class(AIAgent.Model.Message).Create(conversationId, "user", userMessage)
        if '$isobject(userMsg) {
            set result.error = "Failed to save user message"
            return result
        }

        // 3. Build context for the AI bridge
        // Include conversation history, production status, existing classes
        set context = ..BuildContext(conversationId)

        // 4. Send to AI Bridge
        set bridgeResponse = ##class(AIAgent.Engine.BridgeClient).SendMessage(conversationId, userMessage, conv.TargetNamespace, preferredRunner)
        if bridgeResponse.error '= "" {
            set result.error = bridgeResponse.error
            // Save error as system message
            do ##class(AIAgent.Model.Message).Create(conversationId, "system", "Error: "_bridgeResponse.error, "orchestrator")
            return result
        }

        // 5. Save the assistant response
        set responseText = bridgeResponse.%Get("response")
        set agentName = bridgeResponse.%Get("agent")
        set runnerUsed = bridgeResponse.%Get("runner")
        set assistantMsg = ##class(AIAgent.Model.Message).Create(conversationId, "assistant", responseText, agentName, runnerUsed)

        // 6. Check if the response includes generated code
        if $isobject(bridgeResponse.%Get("generation")) {
            set genData = bridgeResponse.generation
            set gen = ##class(AIAgent.Model.Generation).Create(conversationId, genData.%Get("description"), conv.TargetNamespace, runnerUsed)
            if $isobject(gen) {
                set assistantMsg.GenerationId = gen.GenerationId
                do assistantMsg.%Save()

                // Save each generated class
                set classes = genData.%Get("classes")
                if $isobject(classes) {
                    set iter = classes.%GetIterator()
                    while iter.%GetNext(.idx, .cls) {
                        set className = cls.%Get("className")
                        set classType = cls.%Get("classType")
                        set source = cls.%Get("source")

                        // Check if class already exists (for diff)
                        set previousSource = ""
                        if ##class(AIAgent.Engine.CodeManager).ClassExists(className) {
                            do ##class(AIAgent.Engine.CodeManager).ReadClass(className, .previousSource)
                        }

                        do ##class(AIAgent.Model.GenerationClass).Create(gen.GenerationId, className, classType, source, previousSource)
                    }
                }

                set result.generationId = gen.GenerationId
            }
        }

        // 7. Update conversation title if this is the first message
        if conv.Title = "" || (conv.Title = "New Conversation") {
            // Use first 100 chars of user message as title
            set conv.Title = $extract(userMessage, 1, 100)
            do conv.%Save()
        }

        set result.conversationId = conversationId
        set result.messageId = assistantMsg.MessageId
        set result.response = responseText
        set result.agent = agentName
        set result.runner = runnerUsed
    } catch ex {
        set result.error = "Orchestrator error: "_ex.DisplayString()
        do ##class(AIAgent.Util.Logger).Error("Orchestrator", "ProcessMessage failed", ex.DisplayString())
    }
    return result
}

/// Approve a generation and deploy it.
/// Creates a version snapshot, compiles all classes, adds hosts to production.
ClassMethod ApproveAndDeploy(generationId As %String) As %DynamicObject
{
    set result = ##class(%DynamicObject).%New()
    set result.generationId = generationId
    set compileResults = ##class(%DynamicArray).%New()
    try {
        set gen = ##class(AIAgent.Model.Generation).FindById(generationId)
        if '$isobject(gen) {
            set result.error = "Generation '"_generationId_"' not found"
            return result
        }
        if gen.Status '= "preview" {
            set result.error = "Generation is '"_gen.Status_"', expected 'preview'"
            return result
        }

        // 1. Create version snapshot
        set ver = ##class(AIAgent.Engine.VersionManager).CreateSnapshot(generationId, "Pre-deployment snapshot for "_gen.Description)
        if '$isobject(ver) {
            set result.error = "Failed to create version snapshot"
            return result
        }
        set result.versionId = ver.VersionId

        // 2. Mark as approved
        do gen.UpdateStatus("approved")
        set gen.VersionId = ver.VersionId
        do gen.%Save()

        // 3. Compile each class
        set allSuccess = 1
        set sql = "SELECT ID FROM AIAgent_Model.GenerationClass WHERE GenerationId = ?"
        set stmt = ##class(%SQL.Statement).%New()
        do stmt.%Prepare(sql)
        set rs = stmt.%Execute(generationId)

        while rs.%Next() {
            set gc = ##class(AIAgent.Model.GenerationClass).%OpenId(rs.%GetData(1))
            if '$isobject(gc) continue

            set source = gc.GetSource()
            set className = gc.ClassName

            set compileEntry = ##class(%DynamicObject).%New()
            set compileEntry.className = className

            // Write and compile
            set sc = ##class(AIAgent.Engine.CodeManager).WriteClass(className, source, .errMsg)
            if $$$ISOK(sc) {
                do gc.SetCompileResult("success")
                set compileEntry.status = "success"
            } else {
                do gc.SetCompileResult("error", errMsg)
                set compileEntry.status = "error"
                set compileEntry.errors = errMsg
                set allSuccess = 0
            }
            do compileResults.%Push(compileEntry)
        }

        set result.compileResults = compileResults
        set result.allCompiled = allSuccess

        if allSuccess {
            // 4. Mark as deployed
            do gen.UpdateStatus("deployed")

            // 5. Update production if it's running
            try {
                do ##class(AIAgent.Engine.ProductionManager).UpdateProduction()
            } catch {}

            set result.success = 1
            set result.message = "Deployed successfully"
            do ##class(AIAgent.Model.AuditEntry).LogSuccess("deploy", generationId, gen.ClassCount_" classes compiled and deployed")
        } else {
            set result.success = 0
            set result.message = "Some classes failed to compile — deployment incomplete"
            do ##class(AIAgent.Model.AuditEntry).LogFailure("deploy", generationId, "Compilation errors occurred")
        }
    } catch ex {
        set result.error = ex.DisplayString()
        do ##class(AIAgent.Model.AuditEntry).LogFailure("deploy", generationId, ex.DisplayString())
    }
    return result
}

/// Reject a generation (mark as rejected, do not deploy).
ClassMethod RejectGeneration(generationId As %String, reason As %String = "") As %Status
{
    set gen = ##class(AIAgent.Model.Generation).FindById(generationId)
    if '$isobject(gen) {
        return $$$ERROR($$$GeneralError, "Generation not found")
    }
    do gen.UpdateStatus("rejected")
    do ##class(AIAgent.Model.AuditEntry).LogSuccess("reject", generationId, reason)
    return $$$OK
}

/// Build context object for the AI bridge.
/// Includes conversation history and production metadata.
ClassMethod BuildContext(conversationId As %String) As %DynamicObject [ Private ]
{
    set ctx = ##class(%DynamicObject).%New()

    // Conversation history (last 20 messages)
    set messages = ##class(AIAgent.Model.Message).GetByConversation(conversationId)
    set ctx.messages = messages

    // Current production status
    set ctx.productionStatus = ##class(AIAgent.Engine.ProductionManager).GetStatus()

    // Namespace info
    set ctx.namespace = $namespace

    return ctx
}

}
