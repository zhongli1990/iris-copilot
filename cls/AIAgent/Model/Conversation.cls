/// Persistent model: A chat conversation between a user and the AI Agent Platform.
/// Each conversation contains a sequence of messages (see AIAgent.Model.Message).
/// 
/// Part of the IRIS AI Agent Platform (IRIS Copilot).
Class AIAgent.Model.Conversation Extends %Persistent
{

/// Unique conversation identifier (UUID).
Property ConversationId As %String(MAXLEN = 64) [ Required ];

/// Auto-generated title summarizing the conversation's first message.
Property Title As %String(MAXLEN = 500);

/// Detected language of the user's input (ISO 639-1: "en", "es", "zh", etc.).
Property Language As %String(MAXLEN = 10) [ InitialExpression = {"en"} ];

/// Current status: active, archived.
Property Status As %String(MAXLEN = 20) [ InitialExpression = {"active"} ];

/// The IRIS username who started this conversation.
Property CreatedBy As %String(MAXLEN = 200);

/// Timestamp when conversation was created.
Property CreatedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp, 3, 1)} ];

/// Timestamp of last activity.
Property UpdatedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp, 3, 1)} ];

/// Target namespace this conversation operates on (for cross-namespace management).
Property TargetNamespace As %String(MAXLEN = 100);

Index ConversationIdIdx On ConversationId [ Unique ];

Index StatusIdx On Status;

Index CreatedAtIdx On CreatedAt;

/// Create a new conversation. Returns the Conversation object.
ClassMethod Create(title As %String = "", targetNamespace As %String = "", createdBy As %String = "") As AIAgent.Model.Conversation
{
    set conv = ##class(AIAgent.Model.Conversation).%New()
    set conv.ConversationId = ##class(AIAgent.Util.JSON).GenerateId()
    set conv.Title = title
    set conv.TargetNamespace = $select(targetNamespace'="":targetNamespace, 1:$namespace)
    set conv.CreatedBy = $select(createdBy'="":createdBy, 1:$username)
    set sc = conv.%Save()
    if $$$ISERR(sc) {
        do ##class(AIAgent.Util.Logger).Error("Conversation", "Failed to create conversation", $system.Status.GetOneErrorText(sc))
        return ""
    }
    do ##class(AIAgent.Util.Logger).Info("Conversation", "Created conversation", conv.ConversationId)
    return conv
}

/// Find a conversation by its UUID.
ClassMethod FindById(conversationId As %String) As AIAgent.Model.Conversation
{
    set sql = "SELECT ID FROM AIAgent_Model.Conversation WHERE ConversationId = ?"
    set stmt = ##class(%SQL.Statement).%New()
    set sc = stmt.%Prepare(sql)
    quit:$$$ISERR(sc) ""
    set rs = stmt.%Execute(conversationId)
    if rs.%Next() {
        return ##class(AIAgent.Model.Conversation).%OpenId(rs.%GetData(1))
    }
    return ""
}

/// List conversations with pagination. Returns a %DynamicObject with data + meta.
ClassMethod List(page As %Integer = 1, pageSize As %Integer = 20, status As %String = "") As %DynamicObject
{
    // Count total
    set countSql = "SELECT COUNT(*) FROM AIAgent_Model.Conversation"
    if status '= "" { set countSql = countSql _ " WHERE Status = ?" }
    set stmt = ##class(%SQL.Statement).%New()
    do stmt.%Prepare(countSql)
    set rs = $select(status'="":stmt.%Execute(status), 1:stmt.%Execute())
    do rs.%Next()
    set total = rs.%GetData(1)

    // Fetch page
    set offset = (page - 1) * pageSize
    set dataSql = "SELECT ConversationId, Title, Language, Status, CreatedBy, CreatedAt, UpdatedAt, TargetNamespace FROM AIAgent_Model.Conversation"
    if status '= "" { set dataSql = dataSql _ " WHERE Status = ?" }
    set dataSql = dataSql _ " ORDER BY UpdatedAt DESC"

    set stmt2 = ##class(%SQL.Statement).%New()
    do stmt2.%Prepare(dataSql)
    set rs2 = $select(status'="":stmt2.%Execute(status), 1:stmt2.%Execute())

    set arr = ##class(%DynamicArray).%New()
    set skip = 0
    set count = 0
    while rs2.%Next() {
        set skip = skip + 1
        continue:(skip <= offset)
        quit:(count >= pageSize)
        set obj = ##class(%DynamicObject).%New()
        set obj.conversationId = rs2.%GetData(1)
        set obj.title = rs2.%GetData(2)
        set obj.language = rs2.%GetData(3)
        set obj.status = rs2.%GetData(4)
        set obj.createdBy = rs2.%GetData(5)
        set obj.createdAt = rs2.%GetData(6)
        set obj.updatedAt = rs2.%GetData(7)
        set obj.targetNamespace = rs2.%GetData(8)
        do arr.%Push(obj)
        set count = count + 1
    }

    return ##class(AIAgent.Util.JSON).PaginatedResponse(arr, total, page, pageSize)
}

/// Convert to JSON object.
Method ToJSON() As %DynamicObject
{
    set obj = ##class(%DynamicObject).%New()
    set obj.conversationId = ..ConversationId
    set obj.title = ..Title
    set obj.language = ..Language
    set obj.status = ..Status
    set obj.createdBy = ..CreatedBy
    set obj.createdAt = ..CreatedAt
    set obj.updatedAt = ..UpdatedAt
    set obj.targetNamespace = ..TargetNamespace
    return obj
}

/// Touch the UpdatedAt timestamp.
Method Touch() As %Status
{
    set ..UpdatedAt = $zdatetime($ztimestamp, 3, 1)
    return ..%Save()
}

Storage Default
{
<Data name="ConversationDefaultData">
<Subscript>"ConversationDefaultData"</Subscript>
<Value name="1">
<Value>ConversationId</Value>
</Value>
<Value name="2">
<Value>Title</Value>
</Value>
<Value name="3">
<Value>Language</Value>
</Value>
<Value name="4">
<Value>Status</Value>
</Value>
<Value name="5">
<Value>CreatedBy</Value>
</Value>
<Value name="6">
<Value>CreatedAt</Value>
</Value>
<Value name="7">
<Value>UpdatedAt</Value>
</Value>
<Value name="8">
<Value>TargetNamespace</Value>
</Value>
<Value name="9">
<Value>%%CLASSNAME</Value>
</Value>
</Data>
<DataLocation>^AIAgent.ConversationD</DataLocation>
<DefaultData>ConversationDefaultData</DefaultData>
<IdLocation>^AIAgent.ConversationD</IdLocation>
<IndexLocation>^AIAgent.ConversationI</IndexLocation>
<StreamLocation>^AIAgent.ConversationS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
