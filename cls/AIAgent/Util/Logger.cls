/// Structured logging utility for the AI Agent Platform.
/// Writes to the IRIS application log and optionally to a global for in-app querying.
/// 
/// Usage:
///   do ##class(AIAgent.Util.Logger).Info("CodeManager", "Class compiled", className)
///   do ##class(AIAgent.Util.Logger).Error("BridgeClient", "Connection failed", errMsg)
/// 
/// Part of the IRIS AI Agent Platform (IRIS Copilot).
Class AIAgent.Util.Logger [ Abstract ]
{

/// Log global — stores structured log entries for in-app querying.
/// ^AIAgent.Log(seqId) = $lb(timestamp, level, component, message, detail)
Parameter LOGGLOBAL = "^AIAgent.Log";

/// Maximum entries to keep in the log global (FIFO).
Parameter MAXENTRIES = 10000;

/// Log an INFO-level message.
ClassMethod Info(component As %String, message As %String, detail As %String = "")
{
    do ..Write("INFO", component, message, detail)
}

/// Log a WARN-level message.
ClassMethod Warn(component As %String, message As %String, detail As %String = "")
{
    do ..Write("WARN", component, message, detail)
}

/// Log an ERROR-level message.
ClassMethod Error(component As %String, message As %String, detail As %String = "")
{
    do ..Write("ERROR", component, message, detail)
}

/// Log a DEBUG-level message.
ClassMethod Debug(component As %String, message As %String, detail As %String = "")
{
    do ..Write("DEBUG", component, message, detail)
}

/// Internal: write a structured log entry.
ClassMethod Write(level As %String, component As %String, message As %String, detail As %String = "") [ Private ]
{
    set ts = $zdatetime($ztimestamp, 3, 1)
    // Increment the log sequence counter
    set seq = $increment(@..#LOGGLOBAL)
    // Store the entry
    set @..#LOGGLOBAL@(seq) = $listbuild(ts, level, component, message, detail)
    // Purge old entries if over limit
    if seq > ..#MAXENTRIES {
        set oldest = seq - ..#MAXENTRIES
        for i = 1:1:oldest {
            kill:$data(@..#LOGGLOBAL@(i)) @..#LOGGLOBAL@(i)
        }
    }
}

/// Retrieve recent log entries as a %DynamicArray.
/// Returns the last <count> entries, newest first.
ClassMethod GetRecent(count As %Integer = 50) As %DynamicArray
{
    set arr = ##class(%DynamicArray).%New()
    set seq = $get(@..#LOGGLOBAL, 0)
    set start = $select(seq-count+1>0:seq-count+1, 1:1)
    // Iterate newest first
    for i = seq:-1:start {
        if $data(@..#LOGGLOBAL@(i)) {
            set entry = @..#LOGGLOBAL@(i)
            set obj = ##class(%DynamicObject).%New()
            set obj.id = i
            set obj.timestamp = $listget(entry, 1)
            set obj.level = $listget(entry, 2)
            set obj.component = $listget(entry, 3)
            set obj.message = $listget(entry, 4)
            set obj.detail = $listget(entry, 5)
            do arr.%Push(obj)
        }
    }
    return arr
}

/// Clear all log entries.
ClassMethod Clear()
{
    kill @..#LOGGLOBAL
}

}
