/// Persistent model: A code generation batch produced by AI agents.
/// Contains one or more GenerationClass records representing the individual COS classes generated.
/// 
/// Status lifecycle: preview → approved → deployed → (rolled_back) | rejected
/// 
/// Part of the IRIS AI Agent Platform (IRIS Copilot).
Class AIAgent.Model.Generation Extends %Persistent
{

/// Unique generation identifier (UUID).
Property GenerationId As %String(MAXLEN = 64) [ Required ];

/// FK to conversation that triggered this generation.
Property ConversationId As %String(MAXLEN = 64) [ Required ];

/// FK to the assistant message that proposed this generation.
Property MessageId As %String(MAXLEN = 64);

/// Human-readable summary of what was generated.
Property Description As %String(MAXLEN = 2000);

/// Status: preview, approved, deployed, rolled_back, rejected.
Property Status As %String(MAXLEN = 20) [ InitialExpression = {"preview"} ];

/// Number of classes in this generation.
Property ClassCount As %Integer [ InitialExpression = 0 ];

/// The target namespace where classes will be/were deployed.
Property TargetNamespace As %String(MAXLEN = 100);

/// The AI runner used for code generation.
Property RunnerUsed As %String(MAXLEN = 100);

Property CreatedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp, 3, 1)} ];

Property ApprovedAt As %TimeStamp;

Property DeployedAt As %TimeStamp;

Property ApprovedBy As %String(MAXLEN = 200);

/// FK to the Version snapshot created before deployment.
Property VersionId As %String(MAXLEN = 64);

Index GenerationIdIdx On GenerationId [ Unique ];

Index ConversationIdx On ConversationId;

Index StatusIdx On Status;

/// Create a new generation record.
ClassMethod Create(conversationId As %String, description As %String, targetNamespace As %String = "", runnerUsed As %String = "") As AIAgent.Model.Generation
{
    set gen = ##class(AIAgent.Model.Generation).%New()
    set gen.GenerationId = ##class(AIAgent.Util.JSON).GenerateId()
    set gen.ConversationId = conversationId
    set gen.Description = description
    set gen.TargetNamespace = $select(targetNamespace'="":targetNamespace, 1:$namespace)
    set gen.RunnerUsed = runnerUsed
    set sc = gen.%Save()
    if $$$ISERR(sc) {
        do ##class(AIAgent.Util.Logger).Error("Generation", "Failed to create", $system.Status.GetOneErrorText(sc))
        return ""
    }
    do ##class(AIAgent.Util.Logger).Info("Generation", "Created generation", gen.GenerationId)
    return gen
}

/// Find by generation UUID.
ClassMethod FindById(generationId As %String) As AIAgent.Model.Generation
{
    set sql = "SELECT ID FROM AIAgent_Model.Generation WHERE GenerationId = ?"
    set stmt = ##class(%SQL.Statement).%New()
    do stmt.%Prepare(sql)
    set rs = stmt.%Execute(generationId)
    if rs.%Next() {
        return ##class(AIAgent.Model.Generation).%OpenId(rs.%GetData(1))
    }
    return ""
}

/// Find the most recent generation by status (default: preview).
ClassMethod FindLatestByStatus(status As %String = "preview") As AIAgent.Model.Generation
{
    set sql = "SELECT TOP 1 ID FROM AIAgent_Model.Generation WHERE ""Status"" = ? ORDER BY CreatedAt DESC"
    set stmt = ##class(%SQL.Statement).%New()
    set sc = stmt.%Prepare(sql)
    if $$$ISERR(sc) return ""
    set rs = stmt.%Execute(status)
    if rs.%Next() {
        return ##class(AIAgent.Model.Generation).%OpenId(rs.%GetData(1))
    }
    return ""
}

/// Update status and save.
Method UpdateStatus(newStatus As %String, approvedBy As %String = "") As %Status
{
    set ..Status = newStatus
    if newStatus = "approved" {
        set ..ApprovedAt = $zdatetime($ztimestamp, 3, 1)
        set ..ApprovedBy = $select(approvedBy'="":approvedBy, 1:$username)
    }
    if newStatus = "deployed" {
        set ..DeployedAt = $zdatetime($ztimestamp, 3, 1)
    }
    set sc = ..%Save()
    do ##class(AIAgent.Util.Logger).Info("Generation", "Status → "_newStatus, ..GenerationId)
    return sc
}

/// Get all GenerationClass records for this generation.
Method GetClasses() As %DynamicArray
{
    return ##class(AIAgent.Model.GenerationClass).GetByGeneration(..GenerationId)
}

/// Convert to JSON.
Method ToJSON() As %DynamicObject
{
    set obj = ##class(%DynamicObject).%New()
    set obj.generationId = ..GenerationId
    set obj.conversationId = ..ConversationId
    set obj.messageId = ..MessageId
    set obj.description = ..Description
    set obj.status = ..Status
    set obj.classCount = ..ClassCount
    set obj.targetNamespace = ..TargetNamespace
    set obj.runnerUsed = ..RunnerUsed
    set obj.createdAt = ..CreatedAt
    set obj.approvedAt = ..ApprovedAt
    set obj.deployedAt = ..DeployedAt
    set obj.approvedBy = ..ApprovedBy
    set obj.versionId = ..VersionId
    set obj.classes = ..GetClasses()
    return obj
}

Storage Default
{
<Data name="GenerationDefaultData">
<Subscript>"GenerationDefaultData"</Subscript>
<Value name="1">
<Value>GenerationId</Value>
</Value>
<Value name="2">
<Value>ConversationId</Value>
</Value>
<Value name="3">
<Value>MessageId</Value>
</Value>
<Value name="4">
<Value>Description</Value>
</Value>
<Value name="5">
<Value>Status</Value>
</Value>
<Value name="6">
<Value>ClassCount</Value>
</Value>
<Value name="7">
<Value>TargetNamespace</Value>
</Value>
<Value name="8">
<Value>RunnerUsed</Value>
</Value>
<Value name="9">
<Value>CreatedAt</Value>
</Value>
<Value name="10">
<Value>ApprovedAt</Value>
</Value>
<Value name="11">
<Value>DeployedAt</Value>
</Value>
<Value name="12">
<Value>ApprovedBy</Value>
</Value>
<Value name="13">
<Value>VersionId</Value>
</Value>
<Value name="14">
<Value>%%CLASSNAME</Value>
</Value>
</Data>
<DataLocation>^AIAgent.GenerationD</DataLocation>
<DefaultData>GenerationDefaultData</DefaultData>
<IdLocation>^AIAgent.GenerationD</IdLocation>
<IndexLocation>^AIAgent.GenerationI</IndexLocation>
<StreamLocation>^AIAgent.GenerationS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
