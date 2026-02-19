/// Reference implementation for IRIS code import/export operations.
/// Source: Bradford Trust VersionControl system.
/// 
/// Key patterns used by AIAgent.Engine.CodeManager:
///   - $system.OBJ.ExportAllClassesIndividual(dir, flags, "", "", package)
///   - $system.OBJ.LoadDir(directory, "ck/multicompile=0")
///   - $system.OBJ.Export("ClassName.cls", filepath)
///   - $system.OBJ.DeletePackage(packageName)
///   - EnsLib.HL7.SchemaXML.Export(category, filepath)
///   - EnsLib.HL7.SchemaXML.Import(filepath)
///   - Ens.Util.LookupTable.%Export(filepath, tableName)
///   - Ens.Util.LookupTable.%DeleteExtent()
///   - Ens.Director.StopProduction(timeout, force)
///   - Ens.Director.StartProduction(productionName)
///   - Ens.Director.GetProductionStatus(.name, .status)
///   - Ens.Director.RecoverProduction()
///   - Production status codes: 1=Running, 2=Stopped, 3=Suspended, 4=Troubled
/// 
Class VersionControl.UpdateBranch Extends %Persistent
{

// Location of ini.txt file

Parameter INITXT = "C:\VersionControl\ini.txt";

// List of packages to export from BEDDEV namespace

Parameter BEDDEVPKG = "Atmus,BDH,BED,BHD,BHNT,Hl7Service,LDUH,Production,RCL,ReStart,SMSPClient,Temp,User,Util,LDH,LDHLib,java";

// List of packages to export from BEDFORD_PAS_CONNECTIONS namespace

Parameter BEDFORDPASCONNECTIONSPKG = "BDH,Production,RCL";

// List of packeges to export from HEALTHBUS

Parameter HEALTHBUSPKG = "LDH,LDHLib,VersionControl";

// List of packages to export from DASHBOARD, RESULTSBUS, STARLIGHT, ITKM_IN, ITKM_OUT,ITKM, LDH, DOCBUS

Parameter GENERICPKG = "LDH";

Property startingNamespace As %String;

ClassMethod RemoveHL7Schemas()
{
        If ##class(%Dictionary.CompiledClass).%ExistsId("EnsLib.HL7.SchemaDocument") {
            Write !,!,"Deleting Ensemble HL7 Schemas...", !
            Set sc = $$$OK
            Set rs = ##class(%ResultSet).%New("EnsLib.HL7.SchemaDocument:List")
            Do rs.Execute()
            While rs.Next() {
                Set item=rs.Data("name")
                Continue:$listfind($lb("HealthShare_2.5.HL7"),item)
                Set category=$REPLACE(item,".HL7","")
                Set custom = ##class(EnsPortal.HL7.Utils).IsCustomSchema(category)
                If custom {
                    Write "Deleting HL7 schema "_item, !
                    Do ##class(EnsLib.HL7.SchemaDocument).Delete(item)
                }
            }
            Do rs.Close()
            Set rs=""
        }
}

ClassMethod ImportHL7Schemas(directory As %String)
{
        Write !,!,"Importing Ensemble HL7 Schemas...", !
        set dir = directory
        set dir = ##class(%File).NormalizeDirectory(dir)
        set file=$ZSEARCH(dir_"*.HL7")
        while file'="" {
            Write "Importing "_file, !
            Do ##class(EnsLib.HL7.SchemaXML).Import(file)
            set file=$ZSEARCH("")
        }
}

ClassMethod ExportLookups(directory As %String)
{
    write !, "Exporting lookup tables ...", !!
    Do ##class(Ens.Util.LookupTable).%Export(directory_"\AllLookups.xml")

    Set lookupTableFile = ..ReadFile(directory_"\AllLookups.xml",1)
    Set lookupTables = $ListBuild("")

    For lineNumber = 3 : 1 : ($ListLength(lookupTableFile) - 1)
    {
        Set line = $List(lookupTableFile,lineNumber)
        Set lookupTable = $Extract( line,
                                    $Find(line," table="""),
                                    $Find(line,""" ",$Find(line," table=""")) - 3 )
        Set duplicate = 0
        For tableNumber = 1 : 1 : $ListLength(lookupTables)
        {
            If lookupTable = $List(lookupTables,tableNumber)
            {
                Set duplicate = 1
                Quit
            }
        }

        If duplicate = 0
        {
            Set $List(lookupTables,$ListLength(lookupTables) + 1) = lookupTable
            Do ##class(Ens.Util.LookupTable).%Export(directory_"\"_lookupTable_".lut.xml",lookupTable)
        }
    }
    Write !, "Lookup tables have been exported."
    Quit
}

ClassMethod ExportHL7Schemas(directory As %String)
{
    If ##class(%Dictionary.CompiledClass).%ExistsId("EnsLib.HL7.SchemaDocument") {
        Write !,!,"Exporting Ensemble HL7 Schemas..."
        Set sc = $$$OK
        Set rs = ##class(%ResultSet).%New("EnsLib.HL7.SchemaDocument:List")
        Do rs.Execute()
        While rs.Next() {
            Set item=rs.Data("name")
            Continue:$listfind($lb("HealthShare_2.5.HL7"),item)
            Set category=$REPLACE(item,".HL7","")
            Set custom = ##class(EnsPortal.HL7.Utils).IsCustomSchema(category)
            If custom {
                Write !, "Exporting "_directory_"\"_category_".HL7", !
                Do ##class(EnsLib.HL7.SchemaXML).Export(category,directory_"\"_category_".HL7")
            }
        }
        Do rs.Close()
        Set rs=""
    }
    Write !, "HL7 Schemas have been exported."
    Quit
}

ClassMethod GenericExport(directory As %String) As %String
{
    Set status = ..EmptyWorkingDirectory(directory)
    set currentNamespace = $Replace($namespace,"_DEV","")
    write !, "Current namespace is: " _ $NAMESPACE, !

    If currentNamespace = "BEDDEV"
    {
        set packageList = $LFS(..#BEDDEVPKG,",",1)
        for i = 1:1:$LL(packageList){
            Do $system.OBJ.ExportAllClassesIndividual(directory,"/diffexport=1","","",$LISTGET(packageList,i))
        }
        Do $system.OBJ.Export("AtmusWeb.inc",directory_"\Atmus_IncludeFiles.xml")
        Do $system.OBJ.Export("RCLInc.inc",directory_"\RCL_IncludeFiles.xml")
    }
    Else {
        set packageList = $LFS(..#GENERICPKG,",",1)
        for i = 1:1:$LL(packageList){
            Do $system.OBJ.ExportAllClassesIndividual(directory,"/diffexport=1","","",$LISTGET(packageList,i))
            Do $system.OBJ.Export($LISTGET(packageList,i)_".*.inc",directory_"\"_$LISTGET(packageList,i)_"_IncludeFiles.xml")
        }
    }

    Do ..ExportLookups(directory)
    Do ..ExportHL7Schemas(directory)
    Write !!,"The export of classes, lookup tables and HL7Schemas is complete.",!
    Quit status
}

ClassMethod ImportFiles(directory As %String) As %String
{
    set status = ..DeletePackages(directory)
    set status = ""
    Set status = $system.OBJ.LoadDir(directory,"ck/multicompile=0")
    If status = "1"
    {
        Write !,"Files Imported and Compiled"
    }
    Else
    {
        Write !,"Problem importing/compiling files"
    }
    Do ..ImportHL7Schemas(directory)
    Quit ""
}

ClassMethod CheckProductionStatus() As %Integer [ Private ]
{
    Do ##class(Ens.Director).GetProductionStatus(.prodName, .prodStatus)
    Quit prodStatus
}

ClassMethod ReadFile(filepath As %String, deleteFileAfterUse As %Boolean) As %List
{
    Set file = ##class(%Stream.FileCharacter).%New()
    Set file.Filename = filepath
    Set lineNumber = 1
    Set listOfLines = $ListBuild()
    While ('file.AtEnd)
    {
        Set $List(listOfLines,lineNumber) = file.ReadLine()
        Set lineNumber = lineNumber +1
    }
    If deleteFileAfterUse
    {
        Set file.RemoveOnClose = 1
        Do file.Clear()
        Do file.%Close()
    }
    Else
    {
        Set file.RemoveOnClose = 0
        Do file.%Close()
    }
    Quit listOfLines
}

ClassMethod WriteToFile(filepath As %String, listOfLines As %List)
{
    Set outFile = ##class(%Stream.FileCharacter).%New()
    Do outFile.FilenameSet(filepath)
    For lineNumber = 1 : 1 : $ListLength(listOfLines)
    {
        Do outFile.WriteLine($List(listOfLines,lineNumber))
    }
    Do outFile.Flush()
    Do outFile.%Save()
    Set outFile.RemoveOnClose = 0
    Do outFile.%Close()
}

ClassMethod RunShellCommand(ShellCommand As %String) As %String
{
    Set flags="/shell"
    Set command=$PIECE(ShellCommand," ")
    Set parms=""
    Set parmPointer=0
    For i=2:1:$Length(ShellCommand," ")
    {
        Set parmPointer=parmPointer+1
        Set parms(parmPointer)=$PIECE(ShellCommand," ",i)
    }
    Quit $ZF(-100,flags,command,.parms)
}

Storage Default
{
<Data name="UpdateBranchDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>startingNamespace</Value>
</Value>
</Data>
<DataLocation>^VersionControl.UpdateBranchD</DataLocation>
<DefaultData>UpdateBranchDefaultData</DefaultData>
<IdLocation>^VersionControl.UpdateBranchD</IdLocation>
<IndexLocation>^VersionControl.UpdateBranchI</IndexLocation>
<StreamLocation>^VersionControl.UpdateBranchS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
