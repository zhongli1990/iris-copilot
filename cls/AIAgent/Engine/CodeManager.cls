/// Core engine: Manages ObjectScript class lifecycle within IRIS.
/// Write, compile, read, export, delete, and validate COS classes.
/// 
/// Uses IRIS system APIs: $system.OBJ, %Dictionary, %Stream.
/// Patterns derived from VersionControl.UpdateBranch reference implementation.
/// 
/// Part of the IRIS AI Agent Platform (IRIS Copilot).
Class AIAgent.Engine.CodeManager [ Abstract ]
{

/// Default compile flags: c=compile, k=keep generated source.
Parameter COMPILEFLAGS = "ck";

/// Package prefix for all AI-generated classes.
Parameter GENERATEDPREFIX = "AIAgent.Generated";

/// Write a COS class source to the IRIS namespace.
/// The source must be a complete class definition including the Class statement.
/// Returns $$$OK on success, error status on failure.
ClassMethod WriteClass(className As %String, source As %String, Output errMsg As %String) As %Status
{
    set errMsg = ""
    set sc = $$$OK
    try {
        // Write source to a temporary stream
        set stream = ##class(%Stream.TmpCharacter).%New()
        do stream.Write(source)
        do stream.Rewind()

        // Load from stream using UDL format
        set sc = $system.OBJ.LoadStream(stream, ..#COMPILEFLAGS, .errorLog, , 1)
        if $$$ISERR(sc) {
            set errMsg = $system.Status.GetOneErrorText(sc)
        }
        // Check for errors in the error log
        if $data(errorLog) {
            set key = ""
            for {
                set key = $order(errorLog(key))
                quit:key=""
                set errMsg = errMsg _ $select(errMsg'="":" | ", 1:"") _ errorLog(key)
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
        set errMsg = ex.DisplayString()
    }

    // Audit
    if $$$ISOK(sc) {
        do ##class(AIAgent.Util.Logger).Info("CodeManager", "WriteClass OK", className)
        do ##class(AIAgent.Model.AuditEntry).LogSuccess("compile", className, "Compiled successfully")
    } else {
        do ##class(AIAgent.Util.Logger).Error("CodeManager", "WriteClass FAILED", className_": "_errMsg)
        do ##class(AIAgent.Model.AuditEntry).LogFailure("compile", className, errMsg)
    }
    return sc
}

/// Compile an existing class in the namespace.
/// Returns compilation output and any errors.
ClassMethod CompileClass(className As %String, Output log As %String, Output errors As %String) As %Status
{
    set log = ""
    set errors = ""
    set sc = $$$OK
    try {
        set sc = $system.OBJ.Compile(className, ..#COMPILEFLAGS, .errorLog)
        if $data(errorLog) {
            set key = ""
            for {
                set key = $order(errorLog(key))
                quit:key=""
                set errors = errors _ $select(errors'="":" | ", 1:"") _ errorLog(key)
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
        set errors = ex.DisplayString()
    }
    return sc
}

/// Read the full source of a class from the IRIS namespace.
/// Returns the source as a string using UDL export.
ClassMethod ReadClass(className As %String, Output source As %String) As %Status
{
    set source = ""
    set sc = $$$OK
    try {
        // Check class exists
        if '##class(%Dictionary.ClassDefinition).%ExistsId(className) {
            return $$$ERROR($$$GeneralError, "Class '"_className_"' does not exist")
        }
        // Export to a temp stream in UDL format
        set stream = ##class(%Stream.TmpCharacter).%New()
        set sc = $system.OBJ.ExportUDL(className_".cls", .stream)
        if $$$ISOK(sc) {
            do stream.Rewind()
            set source = stream.Read(stream.Size)
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Delete a class from the namespace.
ClassMethod DeleteClass(className As %String) As %Status
{
    set sc = $$$OK
    try {
        if '##class(%Dictionary.ClassDefinition).%ExistsId(className) {
            return $$$ERROR($$$GeneralError, "Class '"_className_"' does not exist")
        }
        set sc = $system.OBJ.Delete(className_".cls")
        if $$$ISOK(sc) {
            do ##class(AIAgent.Model.AuditEntry).LogSuccess("delete", className)
            do ##class(AIAgent.Util.Logger).Info("CodeManager", "Deleted class", className)
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Check if a class exists in the namespace.
ClassMethod ClassExists(className As %String) As %Boolean
{
    return ##class(%Dictionary.ClassDefinition).%ExistsId(className)
}

/// List all classes matching a SQL LIKE pattern.
/// Example: pattern = "AIAgent.Generated.%" or "BRI.Interfaces.Cerner.%"
ClassMethod ListClasses(pattern As %String = "AIAgent.Generated.%") As %DynamicArray
{
    set arr = ##class(%DynamicArray).%New()
    set sql = "SELECT Name, Super FROM %Dictionary.ClassDefinition WHERE Name LIKE ? ORDER BY Name"
    set stmt = ##class(%SQL.Statement).%New()
    do stmt.%Prepare(sql)
    set rs = stmt.%Execute(pattern)
    while rs.%Next() {
        set obj = ##class(%DynamicObject).%New()
        set obj.name = rs.%GetData(1)
        set obj.super = rs.%GetData(2)
        do arr.%Push(obj)
    }
    return arr
}

/// Export all classes matching a pattern to a directory as individual UDL files.
/// Uses $system.OBJ.ExportAllClassesIndividual following the VersionControl pattern.
ClassMethod ExportClasses(pattern As %String, directory As %String) As %Status
{
    set sc = $$$OK
    try {
        // Ensure directory exists
        if '##class(%File).DirectoryExists(directory) {
            do ##class(%File).CreateDirectoryChain(directory)
        }
        // Export using the IRIS system API
        set package = $piece(pattern, ".", 1, *-1)
        set package = $translate(package, "%", "")
        do $system.OBJ.ExportAllClassesIndividual(directory, "/diffexport=1", "", "", package)
        do ##class(AIAgent.Model.AuditEntry).LogSuccess("export", pattern, "Exported to "_directory)
    } catch ex {
        set sc = ex.AsStatus()
        do ##class(AIAgent.Model.AuditEntry).LogFailure("export", pattern, ex.DisplayString())
    }
    return sc
}

/// Import all classes from a directory. Compiles after import.
/// Uses $system.OBJ.LoadDir following the VersionControl pattern.
ClassMethod ImportClasses(directory As %String, Output log As %String) As %Status
{
    set log = ""
    set sc = $$$OK
    try {
        set sc = $system.OBJ.LoadDir(directory, ..#COMPILEFLAGS_"/multicompile=0")
        if $$$ISOK(sc) {
            set log = "Import and compile successful"
            do ##class(AIAgent.Model.AuditEntry).LogSuccess("import", directory, log)
        } else {
            set log = $system.Status.GetOneErrorText(sc)
            do ##class(AIAgent.Model.AuditEntry).LogFailure("import", directory, log)
        }
    } catch ex {
        set sc = ex.AsStatus()
        set log = ex.DisplayString()
    }
    return sc
}

/// Delete an entire package of classes.
/// Uses $system.OBJ.DeletePackage following the VersionControl pattern.
ClassMethod DeletePackage(packageName As %String) As %Status
{
    set sc = $$$OK
    try {
        do $system.OBJ.DeletePackage(packageName)
        do ##class(AIAgent.Model.AuditEntry).LogSuccess("delete", packageName, "Package deleted")
        do ##class(AIAgent.Util.Logger).Info("CodeManager", "Deleted package", packageName)
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Export all custom HL7 schemas to a directory.
/// Following the VersionControl.UpdateBranch.ExportHL7Schemas pattern.
ClassMethod ExportHL7Schemas(directory As %String) As %Status
{
    set sc = $$$OK
    try {
        if '##class(%Dictionary.CompiledClass).%ExistsId("EnsLib.HL7.SchemaDocument") {
            return $$$ERROR($$$GeneralError, "EnsLib.HL7.SchemaDocument not available")
        }
        if '##class(%File).DirectoryExists(directory) {
            do ##class(%File).CreateDirectoryChain(directory)
        }
        set rs = ##class(%ResultSet).%New("EnsLib.HL7.SchemaDocument:List")
        do rs.Execute()
        while rs.Next() {
            set item = rs.Data("name")
            continue:$listfind($lb("HealthShare_2.5.HL7"), item)
            set category = $replace(item, ".HL7", "")
            set custom = ##class(EnsPortal.HL7.Utils).IsCustomSchema(category)
            if custom {
                do ##class(EnsLib.HL7.SchemaXML).Export(category, directory_"/"_category_".HL7")
            }
        }
        do rs.Close()
        do ##class(AIAgent.Model.AuditEntry).LogSuccess("export", "HL7Schemas", "Exported to "_directory)
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Import HL7 schemas from a directory.
/// Following the VersionControl.UpdateBranch.ImportHL7Schemas pattern.
ClassMethod ImportHL7Schemas(directory As %String) As %Status
{
    set sc = $$$OK
    try {
        set dir = ##class(%File).NormalizeDirectory(directory)
        set file = $zsearch(dir_"*.HL7")
        while file '= "" {
            do ##class(EnsLib.HL7.SchemaXML).Import(file)
            do ##class(AIAgent.Util.Logger).Info("CodeManager", "Imported HL7 schema", file)
            set file = $zsearch("")
        }
        do ##class(AIAgent.Model.AuditEntry).LogSuccess("import", "HL7Schemas", "Imported from "_directory)
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Export all lookup tables to a directory.
/// Following the VersionControl.UpdateBranch.ExportLookups pattern.
ClassMethod ExportLookupTables(directory As %String) As %Status
{
    set sc = $$$OK
    try {
        if '##class(%File).DirectoryExists(directory) {
            do ##class(%File).CreateDirectoryChain(directory)
        }
        // Export all to one file first
        do ##class(Ens.Util.LookupTable).%Export(directory_"/AllLookups.xml")

        // Also export individually
        set sql = "SELECT DISTINCT TableName FROM Ens_Util.LookupTable"
        set stmt = ##class(%SQL.Statement).%New()
        do stmt.%Prepare(sql)
        set rs = stmt.%Execute()
        while rs.%Next() {
            set tableName = rs.%GetData(1)
            do ##class(Ens.Util.LookupTable).%Export(directory_"/"_tableName_".lut.xml", tableName)
        }
        do ##class(AIAgent.Model.AuditEntry).LogSuccess("export", "LookupTables", "Exported to "_directory)
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Import a lookup table from an XML file.
ClassMethod ImportLookupTable(filepath As %String) As %Status
{
    set sc = $$$OK
    try {
        set sc = ##class(Ens.Util.LookupTable).%Import(filepath)
        if $$$ISOK(sc) {
            do ##class(AIAgent.Model.AuditEntry).LogSuccess("import", "LookupTable", filepath)
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// List all lookup tables and their entry counts.
ClassMethod ListLookupTables() As %DynamicArray
{
    set arr = ##class(%DynamicArray).%New()
    set sql = "SELECT TableName, COUNT(*) AS EntryCount FROM Ens_Util.LookupTable GROUP BY TableName ORDER BY TableName"
    set stmt = ##class(%SQL.Statement).%New()
    do stmt.%Prepare(sql)
    set rs = stmt.%Execute()
    while rs.%Next() {
        set obj = ##class(%DynamicObject).%New()
        set obj.name = rs.%GetData(1)
        set obj.entryCount = rs.%GetData(2)
        do arr.%Push(obj)
    }
    return arr
}

/// Read entries from a specific lookup table.
ClassMethod ReadLookupTable(tableName As %String) As %DynamicArray
{
    set arr = ##class(%DynamicArray).%New()
    set sql = "SELECT KeyName, DataValue FROM Ens_Util.LookupTable WHERE TableName = ? ORDER BY KeyName"
    set stmt = ##class(%SQL.Statement).%New()
    do stmt.%Prepare(sql)
    set rs = stmt.%Execute(tableName)
    while rs.%Next() {
        set obj = ##class(%DynamicObject).%New()
        set obj.key = rs.%GetData(1)
        set obj.value = rs.%GetData(2)
        do arr.%Push(obj)
    }
    return arr
}

/// Write/update entries in a lookup table.
/// entries is a %DynamicArray of {key, value} objects.
ClassMethod WriteLookupTable(tableName As %String, entries As %DynamicArray) As %Status
{
    set sc = $$$OK
    try {
        set iter = entries.%GetIterator()
        while iter.%GetNext(.idx, .entry) {
            set key = entry.%Get("key")
            set value = entry.%Get("value")
            // Use SQL to insert/update
            &sql(INSERT OR UPDATE INTO Ens_Util.LookupTable (TableName, KeyName, DataValue)
                 VALUES (:tableName, :key, :value))
            if SQLCODE < 0 {
                set sc = $$$ERROR($$$GeneralError, "SQL error inserting lookup entry: "_SQLCODE)
                quit
            }
        }
        if $$$ISOK(sc) {
            do ##class(AIAgent.Model.AuditEntry).LogSuccess("configure", "LookupTable:"_tableName, entries.%Size()_" entries written")
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// List all available HL7 schemas (both standard and custom).
ClassMethod ListHL7Schemas() As %DynamicArray
{
    set arr = ##class(%DynamicArray).%New()
    try {
        if '##class(%Dictionary.CompiledClass).%ExistsId("EnsLib.HL7.SchemaDocument") {
            return arr
        }
        set rs = ##class(%ResultSet).%New("EnsLib.HL7.SchemaDocument:List")
        do rs.Execute()
        while rs.Next() {
            set item = rs.Data("name")
            set category = $replace(item, ".HL7", "")
            set obj = ##class(%DynamicObject).%New()
            set obj.name = item
            set obj.category = category
            try {
                set obj.isCustom = ##class(EnsPortal.HL7.Utils).IsCustomSchema(category)
            } catch {
                set obj.isCustom = 0
            }
            do arr.%Push(obj)
        }
        do rs.Close()
    } catch ex {
        do ##class(AIAgent.Util.Logger).Error("CodeManager", "ListHL7Schemas failed", ex.DisplayString())
    }
    return arr
}

/// Execute a read-only SQL query and return results as a %DynamicArray.
ClassMethod ExecuteSQL(sqlQuery As %String) As %DynamicObject
{
    set result = ##class(%DynamicObject).%New()
    set rows = ##class(%DynamicArray).%New()
    set columns = ##class(%DynamicArray).%New()
    try {
        // Safety check: only allow SELECT statements
        set trimmed = $zstrip(sqlQuery, "<>W")
        if $zconvert($extract(trimmed, 1, 6), "U") '= "SELECT" {
            set result.error = "Only SELECT queries are allowed"
            return result
        }
        set stmt = ##class(%SQL.Statement).%New()
        set sc = stmt.%Prepare(sqlQuery)
        if $$$ISERR(sc) {
            set result.error = $system.Status.GetOneErrorText(sc)
            return result
        }
        set rs = stmt.%Execute()
        // Get column names
        set colCount = rs.%ResultColumnCount
        for i = 1:1:colCount {
            do columns.%Push(rs.%GetColumnName(i))
        }
        // Read rows
        set rowCount = 0
        while rs.%Next() {
            set row = ##class(%DynamicObject).%New()
            for i = 1:1:colCount {
                set colName = rs.%GetColumnName(i)
                do row.%Set(colName, rs.%GetData(i))
            }
            do rows.%Push(row)
            set rowCount = rowCount + 1
            quit:(rowCount >= 1000)  // safety limit
        }
    } catch ex {
        set result.error = ex.DisplayString()
    }
    set result.columns = columns
    set result.rows = rows
    set result.rowCount = rows.%Size()
    return result
}

}
