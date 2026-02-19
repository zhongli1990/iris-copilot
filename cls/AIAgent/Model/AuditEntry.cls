/// Persistent model: Audit trail entry for all AI Agent Platform actions.
/// Every significant action (generate, compile, deploy, rollback, delete, test) is logged.
/// 
/// Part of the IRIS AI Agent Platform (IRIS Copilot).
Class AIAgent.Model.AuditEntry Extends %Persistent
{

/// Timestamp of the action.
Property Timestamp As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp, 3, 1)} ];

/// Action type: generate, compile, deploy, rollback, delete, start, stop, test,
/// approve, reject, configure, import, export.
Property Action As %String(MAXLEN = 50) [ Required ];

/// Who performed the action (IRIS username or agent name).
Property Actor As %String(MAXLEN = 200) [ Required ];

/// Target of the action (class name, production name, version ID, etc.).
Property Target As %String(MAXLEN = 500);

/// JSON blob with action-specific details.
Property Detail As %String(MAXLEN = 10000);

/// Result: success, failure.
Property Status As %String(MAXLEN = 20) [ InitialExpression = {"success"} ];

/// Error detail if status = failure.
Property ErrorDetail As %String(MAXLEN = 10000);

/// FK to conversation (if action was triggered from a conversation).
Property ConversationId As %String(MAXLEN = 64);

/// FK to generation (if action relates to a generation).
Property GenerationId As %String(MAXLEN = 64);

/// The namespace where the action occurred.
Property Namespace As %String(MAXLEN = 100) [ InitialExpression = {$namespace} ];

Index TimestampIdx On Timestamp;

Index ActionIdx On Action;

Index ActorIdx On Actor;

/// Log a successful action.
ClassMethod LogSuccess(action As %String, target As %String, detail As %String = "", conversationId As %String = "", generationId As %String = "") As %Status
{
    return ..Log(action, target, "success", detail, "", conversationId, generationId)
}

/// Log a failed action.
ClassMethod LogFailure(action As %String, target As %String, errorDetail As %String, detail As %String = "", conversationId As %String = "", generationId As %String = "") As %Status
{
    return ..Log(action, target, "failure", detail, errorDetail, conversationId, generationId)
}

/// Internal: create and save an audit entry.
ClassMethod Log(action As %String, target As %String, status As %String, detail As %String, errorDetail As %String, conversationId As %String, generationId As %String) As %Status [ Private ]
{
    set entry = ##class(AIAgent.Model.AuditEntry).%New()
    set entry.Action = action
    set entry.Actor = $username
    set entry.Target = target
    set entry.Status = status
    set entry.Detail = detail
    set entry.ErrorDetail = errorDetail
    set entry.ConversationId = conversationId
    set entry.GenerationId = generationId
    set sc = entry.%Save()
    // Also write to structured logger
    if status = "success" {
        do ##class(AIAgent.Util.Logger).Info("Audit", action_" → "_target, detail)
    } else {
        do ##class(AIAgent.Util.Logger).Error("Audit", action_" FAILED → "_target, errorDetail)
    }
    return sc
}

/// Query recent audit entries with optional filters.
ClassMethod Query(action As %String = "", actor As %String = "", page As %Integer = 1, pageSize As %Integer = 50) As %DynamicArray
{
    set arr = ##class(%DynamicArray).%New()
    set sql = "SELECT ID, Timestamp, Action, Actor, Target, Detail, Status, ErrorDetail, ConversationId, GenerationId, Namespace FROM AIAgent_Model.AuditEntry WHERE 1=1"
    if action '= "" { set sql = sql _ " AND Action = ?" }
    if actor '= "" { set sql = sql _ " AND Actor = ?" }
    set sql = sql _ " ORDER BY Timestamp DESC"

    set stmt = ##class(%SQL.Statement).%New()
    do stmt.%Prepare(sql)

    if (action '= "") && (actor '= "") {
        set rs = stmt.%Execute(action, actor)
    } elseif action '= "" {
        set rs = stmt.%Execute(action)
    } elseif actor '= "" {
        set rs = stmt.%Execute(actor)
    } else {
        set rs = stmt.%Execute()
    }

    set skip = 0
    set offset = (page - 1) * pageSize
    set count = 0
    while rs.%Next() {
        set skip = skip + 1
        continue:(skip <= offset)
        quit:(count >= pageSize)
        set obj = ##class(%DynamicObject).%New()
        set obj.id = rs.%GetData(1)
        set obj.timestamp = rs.%GetData(2)
        set obj.action = rs.%GetData(3)
        set obj.actor = rs.%GetData(4)
        set obj.target = rs.%GetData(5)
        set obj.detail = rs.%GetData(6)
        set obj.status = rs.%GetData(7)
        set obj.errorDetail = rs.%GetData(8)
        set obj.conversationId = rs.%GetData(9)
        set obj.generationId = rs.%GetData(10)
        set obj.namespace = rs.%GetData(11)
        do arr.%Push(obj)
        set count = count + 1
    }
    return arr
}

Storage Default
{
<Data name="AuditEntryDefaultData">
<Subscript>"AuditEntryDefaultData"</Subscript>
<Value name="1">
<Value>Timestamp</Value>
</Value>
<Value name="2">
<Value>Action</Value>
</Value>
<Value name="3">
<Value>Actor</Value>
</Value>
<Value name="4">
<Value>Target</Value>
</Value>
<Value name="5">
<Value>Detail</Value>
</Value>
<Value name="6">
<Value>Status</Value>
</Value>
<Value name="7">
<Value>ErrorDetail</Value>
</Value>
<Value name="8">
<Value>ConversationId</Value>
</Value>
<Value name="9">
<Value>GenerationId</Value>
</Value>
<Value name="10">
<Value>Namespace</Value>
</Value>
<Value name="11">
<Value>%%CLASSNAME</Value>
</Value>
</Data>
<DataLocation>^AIAgent.AuditEntryD</DataLocation>
<DefaultData>AuditEntryDefaultData</DefaultData>
<IdLocation>^AIAgent.AuditEntryD</IdLocation>
<IndexLocation>^AIAgent.AuditEntryI</IndexLocation>
<StreamLocation>^AIAgent.AuditEntryS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
