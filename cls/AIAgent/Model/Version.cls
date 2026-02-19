/// Persistent model: A deployment version snapshot.
/// Created before each deployment so we can roll back.
/// 
/// Part of the IRIS AI Agent Platform (IRIS Copilot).
Class AIAgent.Model.Version Extends %Persistent
{

/// Unique version identifier (e.g., "V-20260217-001").
Property VersionId As %String(MAXLEN = 64) [ Required ];

/// FK to the generation that triggered this snapshot.
Property GenerationId As %String(MAXLEN = 64);

/// Human-readable description of this version.
Property Description As %String(MAXLEN = 2000);

/// Status: active, rolled_back, superseded.
Property Status As %String(MAXLEN = 20) [ InitialExpression = {"active"} ];

/// Number of classes in this snapshot.
Property ClassCount As %Integer [ InitialExpression = 0 ];

/// JSON blob storing the full snapshot: [{className, source}].
/// Using a stream for potentially large snapshots.
Property Snapshot As %Stream.GlobalCharacter;

/// Production configuration snapshot (JSON of Ens.Config items).
Property ProductionSnapshot As %Stream.GlobalCharacter;

/// The namespace this version belongs to.
Property Namespace As %String(MAXLEN = 100);

Property CreatedAt As %TimeStamp [ InitialExpression = {$zdatetime($ztimestamp, 3, 1)} ];

Property CreatedBy As %String(MAXLEN = 200);

Index VersionIdIdx On VersionId [ Unique ];

Index CreatedAtIdx On CreatedAt;

/// Generate the next version ID for today.
ClassMethod NextVersionId() As %String
{
    set dateStr = $zdate($horolog, 8)  // YYYYMMDD
    set prefix = "V-" _ dateStr _ "-"
    // Find the highest existing version for today
    set sql = "SELECT VersionId FROM AIAgent_Model.Version WHERE VersionId LIKE ? ORDER BY VersionId DESC"
    set stmt = ##class(%SQL.Statement).%New()
    do stmt.%Prepare(sql)
    set rs = stmt.%Execute(prefix _ "%")
    if rs.%Next() {
        set lastId = rs.%GetData(1)
        set lastSeq = +$piece(lastId, "-", 3)
        set seq = lastSeq + 1
    } else {
        set seq = 1
    }
    return prefix _ $translate($justify(seq, 3), " ", "0")
}

/// Create a new version snapshot.
ClassMethod Create(generationId As %String, description As %String) As AIAgent.Model.Version
{
    set ver = ##class(AIAgent.Model.Version).%New()
    set ver.VersionId = ..NextVersionId()
    set ver.GenerationId = generationId
    set ver.Description = description
    set ver.Namespace = $namespace
    set ver.CreatedBy = $username
    set sc = ver.%Save()
    if $$$ISERR(sc) {
        do ##class(AIAgent.Util.Logger).Error("Version", "Failed to create", $system.Status.GetOneErrorText(sc))
        return ""
    }
    do ##class(AIAgent.Util.Logger).Info("Version", "Created version", ver.VersionId)
    return ver
}

/// Find by version ID.
ClassMethod FindById(versionId As %String) As AIAgent.Model.Version
{
    set sql = "SELECT ID FROM AIAgent_Model.Version WHERE VersionId = ?"
    set stmt = ##class(%SQL.Statement).%New()
    do stmt.%Prepare(sql)
    set rs = stmt.%Execute(versionId)
    if rs.%Next() {
        return ##class(AIAgent.Model.Version).%OpenId(rs.%GetData(1))
    }
    return ""
}

/// List all versions, newest first.
ClassMethod List(page As %Integer = 1, pageSize As %Integer = 20) As %DynamicArray
{
    set arr = ##class(%DynamicArray).%New()
    set sql = "SELECT VersionId, GenerationId, Description, Status, ClassCount, Namespace, CreatedAt, CreatedBy FROM AIAgent_Model.Version ORDER BY CreatedAt DESC"
    set stmt = ##class(%SQL.Statement).%New()
    do stmt.%Prepare(sql)
    set rs = stmt.%Execute()
    set skip = 0
    set offset = (page - 1) * pageSize
    set count = 0
    while rs.%Next() {
        set skip = skip + 1
        continue:(skip <= offset)
        quit:(count >= pageSize)
        set obj = ##class(%DynamicObject).%New()
        set obj.versionId = rs.%GetData(1)
        set obj.generationId = rs.%GetData(2)
        set obj.description = rs.%GetData(3)
        set obj.status = rs.%GetData(4)
        set obj.classCount = rs.%GetData(5)
        set obj.namespace = rs.%GetData(6)
        set obj.createdAt = rs.%GetData(7)
        set obj.createdBy = rs.%GetData(8)
        do arr.%Push(obj)
        set count = count + 1
    }
    return arr
}

/// Convert to JSON.
Method ToJSON() As %DynamicObject
{
    set obj = ##class(%DynamicObject).%New()
    set obj.versionId = ..VersionId
    set obj.generationId = ..GenerationId
    set obj.description = ..Description
    set obj.status = ..Status
    set obj.classCount = ..ClassCount
    set obj.namespace = ..Namespace
    set obj.createdAt = ..CreatedAt
    set obj.createdBy = ..CreatedBy
    return obj
}

Storage Default
{
<Data name="VersionDefaultData">
<Subscript>"VersionDefaultData"</Subscript>
<Value name="1">
<Value>VersionId</Value>
</Value>
<Value name="2">
<Value>GenerationId</Value>
</Value>
<Value name="3">
<Value>Description</Value>
</Value>
<Value name="4">
<Value>Status</Value>
</Value>
<Value name="5">
<Value>ClassCount</Value>
</Value>
<Value name="6">
<Value>Snapshot</Value>
</Value>
<Value name="7">
<Value>ProductionSnapshot</Value>
</Value>
<Value name="8">
<Value>Namespace</Value>
</Value>
<Value name="9">
<Value>CreatedAt</Value>
</Value>
<Value name="10">
<Value>CreatedBy</Value>
</Value>
<Value name="11">
<Value>%%CLASSNAME</Value>
</Value>
</Data>
<DataLocation>^AIAgent.VersionD</DataLocation>
<DefaultData>VersionDefaultData</DefaultData>
<IdLocation>^AIAgent.VersionD</IdLocation>
<IndexLocation>^AIAgent.VersionI</IndexLocation>
<StreamLocation>^AIAgent.VersionS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
