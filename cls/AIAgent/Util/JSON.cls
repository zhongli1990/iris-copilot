/// JSON utility methods for the AI Agent Platform.
/// Provides helpers for building standard API responses.
/// 
/// Part of the IRIS AI Agent Platform (IRIS Copilot).
/// Deployable as standalone package to any IRIS HealthConnect instance.
Class AIAgent.Util.JSON [ Abstract ]
{

/// Build a standard success response envelope.
/// Returns: {"status":"ok","data":<data>,"meta":<meta>}
ClassMethod SuccessResponse(data As %DynamicAbstractObject = "", meta As %DynamicObject = "") As %DynamicObject
{
    set response = ##class(%DynamicObject).%New()
    set response.status = "ok"
    if $isobject(data) {
        set response.data = data
    } else {
        set response.data = ""
    }
    if $isobject(meta) {
        set response.meta = meta
    }
    return response
}

/// Build a standard error response envelope.
/// Returns: {"status":"error","error":{"code":<code>,"message":<message>}}
ClassMethod ErrorResponse(code As %String, message As %String, httpStatus As %Integer = 500) As %DynamicObject
{
    set %response.Status = httpStatus_" "_$case(httpStatus,
        400:"Bad Request",
        401:"Unauthorized",
        403:"Forbidden",
        404:"Not Found",
        409:"Conflict",
        422:"Unprocessable Entity",
        429:"Too Many Requests",
        :"Error")
    set response = ##class(%DynamicObject).%New()
    set response.status = "error"
    set errObj = ##class(%DynamicObject).%New()
    set errObj.code = code
    set errObj.message = message
    set response.error = errObj
    return response
}

/// Build a paginated response envelope.
/// Returns: {"status":"ok","data":<array>,"meta":{"total":<n>,"page":<p>,"pageSize":<s>,"pages":<t>}}
ClassMethod PaginatedResponse(data As %DynamicArray, total As %Integer, page As %Integer, pageSize As %Integer) As %DynamicObject
{
    set meta = ##class(%DynamicObject).%New()
    set meta.total = total
    set meta.page = page
    set meta.pageSize = pageSize
    set meta.pages = $select(pageSize>0:$zabs(total\pageSize)+$select(total#pageSize>0:1,1:0),1:0)
    return ..SuccessResponse(data, meta)
}

/// Convert a %Status to a JSON error response.
ClassMethod StatusToError(sc As %Status, httpStatus As %Integer = 500) As %DynamicObject
{
    set msg = $system.Status.GetOneErrorText(sc)
    return ..ErrorResponse("IRIS_ERROR", msg, httpStatus)
}

/// Format an IRIS internal date ($horolog day count) to ISO 8601 date string.
ClassMethod FormatDate(internalDate As %String) As %String
{
    quit:internalDate="" ""
    quit $zdate(internalDate, 3)
}

/// Format an IRIS timestamp to ISO 8601.
ClassMethod FormatTimestamp(ts As %TimeStamp) As %String
{
    quit:ts="" ""
    quit $translate(ts, " ", "T")_"Z"
}

/// Write a %DynamicObject or %DynamicArray to the current response as JSON.
ClassMethod WriteJSON(obj As %DynamicAbstractObject)
{
    set %response.ContentType = "application/json"
    set %response.CharSet = "utf-8"
    do obj.%ToJSON()
}

/// Parse the request body as JSON and return a %DynamicObject.
ClassMethod ReadRequestJSON() As %DynamicObject
{
    set body = ""
    while '%request.Content.AtEnd {
        set body = body _ %request.Content.Read()
    }
    quit:body="" ""
    return ##class(%DynamicObject).%FromJSON(body)
}

/// Get a query parameter with a default value.
ClassMethod GetParam(name As %String, default As %String = "") As %String
{
    set val = %request.Get(name)
    quit:val="" default
    quit val
}

/// Get a query parameter as integer with a default value.
ClassMethod GetIntParam(name As %String, default As %Integer = 0) As %Integer
{
    set val = %request.Get(name)
    quit:val="" default
    quit:val'?1.N default
    quit +val
}

/// Generate a UUID-style unique identifier.
ClassMethod GenerateId() As %String
{
    quit $translate($system.Util.CreateGUID(), "{}-", "")
}

/// Get current UTC timestamp in ISO 8601 format.
ClassMethod Now() As %String
{
    quit $zdatetime($ztimestamp, 3, 1)
}

}
