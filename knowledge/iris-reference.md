# IRIS ObjectScript API Reference for AI Agents

This document provides the essential IRIS ObjectScript APIs that AI agents need
to generate correct, production-quality code for HealthConnect integrations.

## 1. Core ObjectScript Syntax

### Variables and Assignments
```objectscript
set myVar = "hello"
set myNum = 42
set myObj = ##class(%DynamicObject).%New()
```

### Control Flow
```objectscript
if condition { ... } elseif condition2 { ... } else { ... }
for i = 1:1:10 { ... }
while condition { ... }
set key = "" for { set key = $order(global(key)) quit:key="" ... }
```

### Error Handling
```objectscript
set sc = $$$OK
try {
    // operations
    set sc = someMethod()
    if $$$ISERR(sc) { /* handle */ }
} catch ex {
    set sc = ex.AsStatus()
    set msg = ex.DisplayString()
}
return sc
```

### Key System Variables
- `$namespace` — current namespace
- `$username` — current user
- `$horolog` — date,time in internal format
- `$ztimestamp` — UTC timestamp
- `$$$OK` — success status
- `$$$ISERR(sc)` — check if status is error
- `$$$ERROR($$$GeneralError, msg)` — create error status

### String Functions
- `$piece(str, delim, from, to)` — extract delimited piece
- `$length(str, delim)` — count pieces
- `$extract(str, from, to)` — substring
- `$find(str, substr)` — find position
- `$replace(str, old, new)` — replace
- `$zstrip(str, action, chars)` — strip characters
- `$zconvert(str, mode)` — "U"=upper, "L"=lower
- `$translate(str, from, to)` — character translation

### List Functions
- `$listbuild(a, b, c)` — create list
- `$listget(list, pos)` — get element
- `$listlength(list)` — count elements
- `$listfind(list, value)` — find position

## 2. JSON / Dynamic Objects
```objectscript
// Create JSON objects
set obj = ##class(%DynamicObject).%New()
set obj.name = "value"
set obj.count = 42
do obj.%Set("key", value)

// Create JSON arrays
set arr = ##class(%DynamicArray).%New()
do arr.%Push("item1")
do arr.%Push(42)

// Iterate
set iter = obj.%GetIterator()
while iter.%GetNext(.key, .val) { ... }

// Serialize/deserialize
set jsonStr = obj.%ToJSON()
set obj = ##class(%DynamicObject).%FromJSON(jsonStr)
```

## 3. SQL from ObjectScript
```objectscript
// Prepared statement (RECOMMENDED)
set sql = "SELECT Name, DOB FROM Patient WHERE MRN = ?"
set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare(sql)
set rs = stmt.%Execute(mrnValue)
while rs.%Next() {
    set name = rs.%GetData(1)
    set dob = rs.%GetData(2)
}

// Embedded SQL
&sql(SELECT Name INTO :name FROM Patient WHERE ID = :id)
if SQLCODE = 0 { /* found */ }
```

## 4. Streams
```objectscript
// Character stream (for text)
set stream = ##class(%Stream.GlobalCharacter).%New()
do stream.Write("content")
do stream.Rewind()
set content = stream.Read(stream.Size)

// File stream
set file = ##class(%Stream.FileCharacter).%New()
do file.FilenameSet("C:\path\file.txt")
do file.Write("content")
do file.%Save()

// Binary stream
set bin = ##class(%Stream.GlobalBinary).%New()
```

## 5. Class Definition APIs
```objectscript
// Check if class exists
set exists = ##class(%Dictionary.ClassDefinition).%ExistsId("My.ClassName")

// Load/compile class from source
set sc = $system.OBJ.LoadStream(stream, "ck")
set sc = $system.OBJ.Compile("My.ClassName", "ck")
set sc = $system.OBJ.LoadDir(directory, "ck")

// Export class
set sc = $system.OBJ.ExportUDL("My.ClassName.cls", .stream)
do $system.OBJ.ExportAllClassesIndividual(dir, "/diffexport=1", "", "", "PackageName")

// Delete class
set sc = $system.OBJ.Delete("My.ClassName.cls")
do $system.OBJ.DeletePackage("PackageName")
```

## 6. HealthConnect / Ensemble Production APIs

### Production Lifecycle
```objectscript
// Get status: 1=Running, 2=Stopped, 3=Suspended, 4=Troubled
do ##class(Ens.Director).GetProductionStatus(.prodName, .prodStatus)

// Start/stop
set sc = ##class(Ens.Director).StartProduction("My.ProductionClass")
set sc = ##class(Ens.Director).StopProduction(300, 1)

// Update running production (apply config changes)
set sc = ##class(Ens.Director).UpdateProduction()

// Enable/disable a specific host
set sc = ##class(Ens.Director).EnableConfigItem("HostName", enabled, 1)

// Recover troubled production
do ##class(Ens.Director).RecoverProduction()
```

### Production Configuration
```objectscript
// Open production definition
set prod = ##class(Ens.Config.Production).%OpenId("My.ProductionClass")

// Iterate items (business hosts)
for i = 1:1:prod.Items.Count() {
    set item = prod.Items.GetAt(i)
    // item.Name, item.ClassName, item.Category, item.Enabled, item.Settings
}

// Add new item
set item = ##class(Ens.Config.Item).%New()
set item.Name = "My New Service"
set item.ClassName = "My.Service.Class"
set item.Category = "MyCategory"
set item.Enabled = 1
set item.Settings = "Port=5000,AckMode=Application"
do prod.Items.Insert(item)
set sc = prod.%Save()
```

### Business Service Pattern
```objectscript
Class My.Service Extends Ens.BusinessService
{
Parameter ADAPTER = "EnsLib.HL7.Adapter.TCPInboundAdapter";
Parameter SETTINGS = "TargetConfigNames";
Property TargetConfigNames As %String(MAXLEN = 1000);

Method OnProcessInput(pInput As EnsLib.HL7.Message, Output pOutput As EnsLib.HL7.Message) As %Status
{
    set sc = ..SendRequestAsync(..TargetConfigNames, pInput)
    return sc
}
}
```

### Business Process (BPL) Pattern
```objectscript
Class My.Process Extends Ens.BusinessProcessBPL
{
Parameter SETTINGS = "CustomSetting";
Property CustomSetting As %String;

XData BPL [ XMLNamespace = "http://www.intersystems.com/bpl" ]
{
<process language='objectscript' request='EnsLib.HL7.Message' response='Ens.Response'>
<sequence>
  <assign property="context.value" value="request.GetValueAt(&quot;PID:3.1&quot;)" />
  <if condition="context.value &apos;= &quot;&quot;">
    <true>
      <call target="MyOperation" async="1">
        <request type="Ens.StringContainer">
          <assign property="callrequest.StringValue" value="context.value" />
        </request>
      </call>
    </true>
  </if>
</sequence>
</process>
}
}
```

### Business Operation Pattern
```objectscript
Class My.Operation Extends Ens.BusinessOperation
{
Parameter ADAPTER = "EnsLib.HL7.Operation.TCPOperation";

Method SendHL7(pRequest As EnsLib.HL7.Message, Output pResponse As EnsLib.HL7.Message) As %Status
{
    return ..Adapter.SendMessageSync(pRequest, .pResponse)
}

XData MessageMap
{
<MapItems>
  <MapItem MessageType="EnsLib.HL7.Message">
    <Method>SendHL7</Method>
  </MapItem>
</MapItems>
}
}
```

### Routing Rule Pattern
```objectscript
Class My.Router Extends Ens.Rule.Definition
{
Parameter RuleAssistClass = "EnsLib.HL7.MsgRouter.RuleAssist";

XData RuleDefinition [ XMLNamespace = "http://www.intersystems.com/rule" ]
{
<ruleDefinition>
<ruleset name="" effectiveBegin="" effectiveEnd="">
  <rule name="Route ADT A01">
    <constraint name="docType" value="2.4:ADT_A01" />
    <constraint name="msgType" value="ADT" />
    <when condition="1">
      <send transform="" target="My Target Operation" />
    </when>
  </rule>
</ruleset>
</ruleDefinition>
}
}
```

### Data Transformation (DTL) Pattern
```objectscript
Class My.Transform Extends Ens.DataTransformDTL [ DependsOn = (EnsLib.HL7.Message) ]
{
Parameter IGNOREMISSINGSOURCE = 1;
Parameter REPORTERRORS = 1;
Parameter TREATEMPTYREPEATINGFIELDASNULL = 0;

XData DTL [ XMLNamespace = "http://www.intersystems.com/dtl" ]
{
<transform sourceClass='EnsLib.HL7.Message' targetClass='EnsLib.HL7.Message'
           sourceDocType='2.4:ADT_A01' targetDocType='2.4:ADT_A01'>
  <assign value='source.{MSH:3}' property='target.{MSH:3}' />
  <assign value='source.{PID:3.1}' property='target.{PID:3.1}' />
  <assign value='"TRANSFORMED"' property='target.{MSH:5}' />
</transform>
}
}
```

## 7. HL7 Message Manipulation
```objectscript
// Create HL7 message
set msg = ##class(EnsLib.HL7.Message).%New()
do msg.PokeDocType("2.4:ADT_A01")

// Set field values
do msg.SetValueAt("ADT", "MSH:9.1")
do msg.SetValueAt("A01", "MSH:9.2")
do msg.SetValueAt(mrn, "PID:3(1).1")
do msg.SetValueAt(lastName, "PID:5.1")
do msg.SetValueAt(firstName, "PID:5.2")

// Get field values
set msgType = msg.GetValueAt("MSH:9.1")
set mrn = msg.GetValueAt("PID:3(1).1")

// Segment iteration
set segCount = msg.SegCount
for i = 1:1:segCount {
    set seg = msg.GetSegmentAt(i)
    set segName = seg.Name
}
```

## 8. Lookup Tables
```objectscript
// Read a value
set maxDose = ##class(Ens.Util.FunctionSet).Lookup("PharmDoseLimit", drugCode, defaultValue)

// Export/Import
do ##class(Ens.Util.LookupTable).%Export(filepath, tableName)
set sc = ##class(Ens.Util.LookupTable).%Import(filepath)
```

## 9. Common Adapters

| Adapter | Direction | Protocol |
|---------|-----------|----------|
| `EnsLib.HL7.Adapter.TCPInboundAdapter` | Inbound | HL7 over TCP/MLLP |
| `EnsLib.HL7.Operation.TCPOperation` | Outbound | HL7 over TCP/MLLP |
| `EnsLib.HTTP.InboundAdapter` | Inbound | HTTP |
| `EnsLib.HTTP.OutboundAdapter` | Outbound | HTTP |
| `EnsLib.File.InboundAdapter` | Inbound | File polling |
| `EnsLib.File.OutboundAdapter` | Outbound | File writing |
| `EnsLib.SQL.InboundAdapter` | Inbound | SQL polling |
| `EnsLib.SQL.OutboundAdapter` | Outbound | SQL insert/update |
| `EnsLib.EMail.OutboundAdapter` | Outbound | SMTP email |
| `EnsLib.SOAP.OutboundAdapter` | Outbound | SOAP web services |
| `EnsLib.REST.Operation` | Outbound | REST HTTP |

## 10. File System Operations
```objectscript
// Check existence
set exists = ##class(%File).Exists(filepath)
set dirExists = ##class(%File).DirectoryExists(dirpath)

// Create directory chain
do ##class(%File).CreateDirectoryChain(dirpath)

// Normalize path
set normalized = ##class(%File).NormalizeDirectory(dirpath)
```
