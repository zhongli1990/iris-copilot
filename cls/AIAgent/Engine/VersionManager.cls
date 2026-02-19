/// Core engine: Version control for AI-generated code.
/// Creates snapshots before deployment and supports rollback.
/// 
/// Part of the IRIS AI Agent Platform (IRIS Copilot).
Class AIAgent.Engine.VersionManager [ Abstract ]
{

/// Create a snapshot of the current state of classes that will be affected by a generation.
/// Captures the source of each class (if it exists) so we can restore on rollback.
ClassMethod CreateSnapshot(generationId As %String, description As %String = "") As AIAgent.Model.Version
{
    set ver = ##class(AIAgent.Model.Version).Create(generationId, description)
    if '$isobject(ver) {
        return ""
    }

    // Get the generation to find which classes are being deployed
    set gen = ##class(AIAgent.Model.Generation).FindById(generationId)
    if '$isobject(gen) {
        do ##class(AIAgent.Util.Logger).Error("VersionManager", "Generation not found", generationId)
        return ""
    }

    // Build snapshot: array of {className, source} for each class that currently exists
    set snapshot = ##class(%DynamicArray).%New()
    set classCount = 0

    // Query all GenerationClass records for this generation
    set sql = "SELECT ID FROM AIAgent_Model.GenerationClass WHERE GenerationId = ?"
    set stmt = ##class(%SQL.Statement).%New()
    do stmt.%Prepare(sql)
    set rs = stmt.%Execute(generationId)

    while rs.%Next() {
        set gc = ##class(AIAgent.Model.GenerationClass).%OpenId(rs.%GetData(1))
        if $isobject(gc) {
            set className = gc.ClassName
            set entry = ##class(%DynamicObject).%New()
            set entry.className = className

            // Capture current source (if class exists)
            if ##class(AIAgent.Engine.CodeManager).ClassExists(className) {
                set sc = ##class(AIAgent.Engine.CodeManager).ReadClass(className, .currentSource)
                if $$$ISOK(sc) {
                    set entry.source = currentSource
                    set entry.existed = 1
                }
            } else {
                set entry.source = ""
                set entry.existed = 0
            }
            do snapshot.%Push(entry)
            set classCount = classCount + 1
        }
    }

    // Save snapshot to version
    do ver.Snapshot.Write(snapshot.%ToJSON())
    set ver.ClassCount = classCount

    // Also snapshot production config
    set topology = ##class(AIAgent.Engine.ProductionManager).GetTopology()
    do ver.ProductionSnapshot.Write(topology.%ToJSON())

    do ver.%Save()
    do ##class(AIAgent.Util.Logger).Info("VersionManager", "Snapshot created", ver.VersionId_" ("_classCount_" classes)")
    return ver
}

/// Rollback to a previous version.
/// Restores all class sources from the snapshot and recompiles.
ClassMethod Rollback(versionId As %String, Output log As %String) As %Status
{
    set log = ""
    set sc = $$$OK

    set ver = ##class(AIAgent.Model.Version).FindById(versionId)
    if '$isobject(ver) {
        return $$$ERROR($$$GeneralError, "Version '"_versionId_"' not found")
    }

    // Read the snapshot
    do ver.Snapshot.Rewind()
    set snapshotJSON = ver.Snapshot.Read(ver.Snapshot.Size)
    if snapshotJSON = "" {
        return $$$ERROR($$$GeneralError, "Version snapshot is empty")
    }

    set snapshot = ##class(%DynamicArray).%FromJSON(snapshotJSON)
    set iter = snapshot.%GetIterator()
    set restoredCount = 0
    set deletedCount = 0
    set errors = ""

    while iter.%GetNext(.idx, .entry) {
        set className = entry.%Get("className")
        set source = entry.%Get("source")
        set existed = entry.%Get("existed")

        if existed && (source '= "") {
            // Restore the previous source
            set sc2 = ##class(AIAgent.Engine.CodeManager).WriteClass(className, source, .errMsg)
            if $$$ISOK(sc2) {
                set restoredCount = restoredCount + 1
            } else {
                set errors = errors _ className _ ": " _ errMsg _ "; "
            }
        } elseif 'existed {
            // Class didn't exist before — delete it
            if ##class(AIAgent.Engine.CodeManager).ClassExists(className) {
                set sc2 = ##class(AIAgent.Engine.CodeManager).DeleteClass(className)
                if $$$ISOK(sc2) {
                    set deletedCount = deletedCount + 1
                }
            }
        }
    }

    // Update version status
    set ver.Status = "rolled_back"
    do ver.%Save()

    // Also mark the associated generation as rolled_back
    if ver.GenerationId '= "" {
        set gen = ##class(AIAgent.Model.Generation).FindById(ver.GenerationId)
        if $isobject(gen) {
            do gen.UpdateStatus("rolled_back")
        }
    }

    set log = "Rollback to "_versionId_": restored "_restoredCount_" classes, deleted "_deletedCount_" new classes"
    if errors '= "" {
        set log = log _ ". Errors: " _ errors
        set sc = $$$ERROR($$$GeneralError, errors)
        do ##class(AIAgent.Model.AuditEntry).LogFailure("rollback", versionId, errors, log)
    } else {
        do ##class(AIAgent.Model.AuditEntry).LogSuccess("rollback", versionId, log)
    }

    // Update production to apply changes
    do ##class(AIAgent.Engine.ProductionManager).UpdateProduction()

    do ##class(AIAgent.Util.Logger).Info("VersionManager", "Rollback complete", log)
    return sc
}

/// List all versions, newest first.
ClassMethod ListVersions(page As %Integer = 1, pageSize As %Integer = 20) As %DynamicArray
{
    return ##class(AIAgent.Model.Version).List(page, pageSize)
}

/// Get a specific version details.
ClassMethod GetVersion(versionId As %String) As %DynamicObject
{
    set ver = ##class(AIAgent.Model.Version).FindById(versionId)
    if '$isobject(ver) {
        return ""
    }
    return ver.ToJSON()
}

/// Export a version as an XML deployment package to a directory.
/// Exports all class sources from the snapshot to individual .cls files.
ClassMethod ExportVersion(versionId As %String, directory As %String) As %Status
{
    set sc = $$$OK
    try {
        set ver = ##class(AIAgent.Model.Version).FindById(versionId)
        if '$isobject(ver) {
            return $$$ERROR($$$GeneralError, "Version not found")
        }

        // Ensure directory exists
        if '##class(%File).DirectoryExists(directory) {
            do ##class(%File).CreateDirectoryChain(directory)
        }

        // Read snapshot and write each class source to a file
        do ver.Snapshot.Rewind()
        set snapshotJSON = ver.Snapshot.Read(ver.Snapshot.Size)
        set snapshot = ##class(%DynamicArray).%FromJSON(snapshotJSON)
        set iter = snapshot.%GetIterator()

        while iter.%GetNext(.idx, .entry) {
            set className = entry.%Get("className")
            set source = entry.%Get("source")
            if source '= "" {
                set fileName = $translate(className, ".", "/") _ ".cls"
                // Ensure subdirectories exist
                set subDir = directory _ "/" _ $piece(fileName, "/", 1, *-1)
                if '##class(%File).DirectoryExists(subDir) {
                    do ##class(%File).CreateDirectoryChain(subDir)
                }
                set file = ##class(%Stream.FileCharacter).%New()
                do file.FilenameSet(directory _ "/" _ fileName)
                do file.Write(source)
                do file.%Save()
                do file.%Close()
            }
        }

        do ##class(AIAgent.Model.AuditEntry).LogSuccess("export", versionId, "Exported to "_directory)
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

}
