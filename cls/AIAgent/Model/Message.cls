/// Persistent model: An individual chat message within a conversation.
/// 
/// Part of the IRIS AI Agent Platform (IRIS Copilot).
Class AIAgent.Model.Message Extends %Persistent
{

/// FK to AIAgent.Model.Conversation.ConversationId.
Property ConversationId As %String(MAXLEN = 64) [ Required ];

/// Unique message identifier (UUID).
Property MessageId As %String(MAXLEN = 64) [ Required ];

/// Role: "user", "assistant", "system".
Property Role As %String(MAXLEN = 20) [ Required ];

/// Message content. Uses a stream to support large AI responses.
Property Content As %Stream.GlobalCharacter;

/// Timestamp when message was created.
Property Timestamp As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp, 3, 1)} ];

/// Token count (if available from AI runner).
Property TokenCount As %Integer [ InitialExpression = 0 ];

/// Which AI agent generated this message (orchestrator, architect, developer, etc.).
Property AgentName As %String(MAXLEN = 100);

/// Which AI runner was used (claude-agent-sdk, openai-codex, etc.).
Property RunnerUsed As %String(MAXLEN = 100);

/// FK to AIAgent.Model.Generation.GenerationId if this message resulted in code generation.
Property GenerationId As %String(MAXLEN = 64);

Index ConversationIdx On ConversationId;

Index MessageIdIdx On MessageId [ Unique ];

Index TimestampIdx On Timestamp;

/// Create a new message in a conversation.
ClassMethod Create(conversationId As %String, role As %String, content As %String, agentName As %String = "", runnerUsed As %String = "") As AIAgent.Model.Message
{
    set msg = ##class(AIAgent.Model.Message).%New()
    set msg.ConversationId = conversationId
    set msg.MessageId = ##class(AIAgent.Util.JSON).GenerateId()
    set msg.Role = role
    do msg.Content.Write(content)
    set msg.AgentName = agentName
    set msg.RunnerUsed = runnerUsed
    set sc = msg.%Save()
    if $$$ISERR(sc) {
        do ##class(AIAgent.Util.Logger).Error("Message", "Failed to save message", $system.Status.GetOneErrorText(sc))
        return ""
    }
    // Touch the parent conversation
    set conv = ##class(AIAgent.Model.Conversation).FindById(conversationId)
    if $isobject(conv) { do conv.Touch() }
    return msg
}

/// Get all messages for a conversation, ordered by timestamp.
ClassMethod GetByConversation(conversationId As %String) As %DynamicArray
{
    set arr = ##class(%DynamicArray).%New()
    set sql = "SELECT ID FROM AIAgent_Model.Message WHERE ConversationId = ? ORDER BY Timestamp ASC"
    set stmt = ##class(%SQL.Statement).%New()
    do stmt.%Prepare(sql)
    set rs = stmt.%Execute(conversationId)
    while rs.%Next() {
        set msg = ##class(AIAgent.Model.Message).%OpenId(rs.%GetData(1))
        if $isobject(msg) {
            do arr.%Push(msg.ToJSON())
        }
    }
    return arr
}

/// Convert to JSON object.
Method ToJSON() As %DynamicObject
{
    set obj = ##class(%DynamicObject).%New()
    set obj.messageId = ..MessageId
    set obj.conversationId = ..ConversationId
    set obj.role = ..Role
    // Read content from stream
    do ..Content.Rewind()
    set obj.content = ..Content.Read(..Content.Size)
    set obj.timestamp = ..Timestamp
    set obj.tokenCount = ..TokenCount
    set obj.agentName = ..AgentName
    set obj.runnerUsed = ..RunnerUsed
    set obj.generationId = ..GenerationId
    return obj
}

Storage Default
{
<Data name="MessageDefaultData">
<Subscript>"MessageDefaultData"</Subscript>
<Value name="1">
<Value>ConversationId</Value>
</Value>
<Value name="2">
<Value>MessageId</Value>
</Value>
<Value name="3">
<Value>Role</Value>
</Value>
<Value name="4">
<Value>Content</Value>
</Value>
<Value name="5">
<Value>Timestamp</Value>
</Value>
<Value name="6">
<Value>TokenCount</Value>
</Value>
<Value name="7">
<Value>AgentName</Value>
</Value>
<Value name="8">
<Value>RunnerUsed</Value>
</Value>
<Value name="9">
<Value>GenerationId</Value>
</Value>
<Value name="10">
<Value>%%CLASSNAME</Value>
</Value>
</Data>
<DataLocation>^AIAgent.MessageD</DataLocation>
<DefaultData>MessageDefaultData</DefaultData>
<IdLocation>^AIAgent.MessageD</IdLocation>
<IndexLocation>^AIAgent.MessageI</IndexLocation>
<StreamLocation>^AIAgent.MessageS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
