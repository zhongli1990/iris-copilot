/// Persistent model: An individual COS class within a code generation batch.
/// 
/// Part of the IRIS AI Agent Platform (IRIS Copilot).
Class AIAgent.Model.GenerationClass Extends %Persistent
{

/// FK to AIAgent.Model.Generation.GenerationId.
Property GenerationId As %String(MAXLEN = 64) [ Required ];

/// Fully qualified class name (e.g., "AIAgent.Generated.Pharmacy.Process.DoseCheckProcess").
Property ClassName As %String(MAXLEN = 500) [ Required ];

/// Component type: BusinessService, BusinessProcess, BusinessOperation, Message,
/// Transform, RoutingRule, LookupTable, Test, Other.
Property ClassType As %String(MAXLEN = 50);

/// The generated ObjectScript source code.
Property Source As %Stream.GlobalCharacter;

/// The previous source of this class (if it existed before), for diff/rollback.
Property PreviousSource As %Stream.GlobalCharacter;

/// Compilation status: pending, success, error.
Property CompileStatus As %String(MAXLEN = 20) [ InitialExpression = {"pending"} ];

/// Compilation error messages (if any).
Property CompileErrors As %String(MAXLEN = 10000);

/// Whether this class existed before (true = modification, false = new class).
Property IsModification As %Boolean [ InitialExpression = 0 ];

Index GenerationIdx On GenerationId;

Index ClassNameIdx On ClassName;

/// Create a new generation class record.
ClassMethod Create(generationId As %String, className As %String, classType As %String, source As %String, previousSource As %String = "") As AIAgent.Model.GenerationClass
{
    set gc = ##class(AIAgent.Model.GenerationClass).%New()
    set gc.GenerationId = generationId
    set gc.ClassName = className
    set gc.ClassType = classType
    do gc.Source.Write(source)
    if previousSource '= "" {
        do gc.PreviousSource.Write(previousSource)
        set gc.IsModification = 1
    }
    set sc = gc.%Save()
    if $$$ISERR(sc) {
        do ##class(AIAgent.Util.Logger).Error("GenerationClass", "Failed to save", className_": "_$system.Status.GetOneErrorText(sc))
        return ""
    }
    // Increment class count on parent generation
    set gen = ##class(AIAgent.Model.Generation).FindById(generationId)
    if $isobject(gen) {
        set gen.ClassCount = gen.ClassCount + 1
        do gen.%Save()
    }
    return gc
}

/// Get all classes for a generation.
ClassMethod GetByGeneration(generationId As %String) As %DynamicArray
{
    set arr = ##class(%DynamicArray).%New()
    set sql = "SELECT ID FROM AIAgent_Model.GenerationClass WHERE GenerationId = ? ORDER BY ID"
    set stmt = ##class(%SQL.Statement).%New()
    do stmt.%Prepare(sql)
    set rs = stmt.%Execute(generationId)
    while rs.%Next() {
        set gc = ##class(AIAgent.Model.GenerationClass).%OpenId(rs.%GetData(1))
        if $isobject(gc) {
            do arr.%Push(gc.ToJSON())
        }
    }
    return arr
}

/// Update compilation status.
Method SetCompileResult(status As %String, errors As %String = "") As %Status
{
    set ..CompileStatus = status
    set ..CompileErrors = errors
    return ..%Save()
}

/// Read source as string.
Method GetSource() As %String
{
    do ..Source.Rewind()
    return ..Source.Read(..Source.Size)
}

/// Read previous source as string.
Method GetPreviousSource() As %String
{
    quit:..PreviousSource.Size=0 ""
    do ..PreviousSource.Rewind()
    return ..PreviousSource.Read(..PreviousSource.Size)
}

/// Convert to JSON.
Method ToJSON() As %DynamicObject
{
    set obj = ##class(%DynamicObject).%New()
    set obj.generationId = ..GenerationId
    set obj.className = ..ClassName
    set obj.classType = ..ClassType
    set obj.source = ..GetSource()
    set obj.compileStatus = ..CompileStatus
    set obj.compileErrors = ..CompileErrors
    set obj.isModification = ..IsModification
    return obj
}

Storage Default
{
<Data name="GenerationClassDefaultData">
<Subscript>"GenerationClassDefaultData"</Subscript>
<Value name="1">
<Value>GenerationId</Value>
</Value>
<Value name="2">
<Value>ClassName</Value>
</Value>
<Value name="3">
<Value>ClassType</Value>
</Value>
<Value name="4">
<Value>Source</Value>
</Value>
<Value name="5">
<Value>PreviousSource</Value>
</Value>
<Value name="6">
<Value>CompileStatus</Value>
</Value>
<Value name="7">
<Value>CompileErrors</Value>
</Value>
<Value name="8">
<Value>IsModification</Value>
</Value>
<Value name="9">
<Value>%%CLASSNAME</Value>
</Value>
</Data>
<DataLocation>^AIAgent.GenerationClassD</DataLocation>
<DefaultData>GenerationClassDefaultData</DefaultData>
<IdLocation>^AIAgent.GenerationClassD</IdLocation>
<IndexLocation>^AIAgent.GenerationClassI</IndexLocation>
<StreamLocation>^AIAgent.GenerationClassS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
