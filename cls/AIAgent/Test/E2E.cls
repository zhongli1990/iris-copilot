/// IRIS-side E2E probes for generic gateway and bridge APIs.
/// Run from IRIS terminal:
///   do ##class(AIAgent.Test.E2E).Run()
Class AIAgent.Test.E2E [ Abstract ]
{

ClassMethod Run(bridgeBase As %String = "http://localhost:3100", irisBase As %String = "http://localhost:52773", ns As %String = "") As %Status
{
    set sc = $$$OK
    if ns = "" set ns = $namespace

    write !, "AIAgent.Test.E2E starting..."
    write !, "  bridgeBase: ", bridgeBase
    write !, "  irisBase:   ", irisBase
    write !, "  namespace:  ", ns, !

    do ..RunCase("bridge-health", bridgeBase_"/api/health", "GET", "", "status", "ok", .sc)
    do ..RunCase("iris-health", irisBase_"/ai/health", "GET", "", "status", "ok", .sc)

    set body = ##class(%DynamicObject).%New()
    set body.namespace = ns
    set body.op = "query"
    set body.target = "production/topology"
    set body.action = "read"
    set body.args = ##class(%DynamicObject).%New()
    set body.dryRun = 0
    do ..RunCase("operate-topology", bridgeBase_"/api/iris/operate", "POST", body.%ToJSON(), "status", "ok", .sc)

    set body2 = ##class(%DynamicObject).%New()
    set body2.namespace = ns
    set body2.op = "discover"
    set body2.target = "invoke-policy"
    set body2.action = "read"
    set body2.args = ##class(%DynamicObject).%New()
    set body2.dryRun = 0
    do ..RunCase("operate-invoke-policy", bridgeBase_"/api/iris/operate", "POST", body2.%ToJSON(), "status", "ok", .sc)

    set body3 = ##class(%DynamicObject).%New()
    set body3.namespace = ns
    set body3.conversationId = "iris-e2e-"_$piece($horolog,",",2)
    set body3.preferredRunner = "openai-codex-sdk"
    set body3.message = "list classes in the BRI.* packages"
    do ..RunCase("chat-class-query", bridgeBase_"/api/chat", "POST", body3.%ToJSON(), "runner", "", .sc)

    set body4 = ##class(%DynamicObject).%New()
    set body4.namespace = ns
    set body4.conversationId = "iris-e2e-"_$piece($horolog,",",2)_"-2"
    set body4.preferredRunner = "openai-codex-sdk"
    set body4.message = "Create a plan to add a disabled test business host named AIAgent.DryRun.TestHost, dry-run only."
    do ..RunCase("chat-dryrun-host-add", bridgeBase_"/api/chat", "POST", body4.%ToJSON(), "runner", "", .sc)

    write !, "AIAgent.Test.E2E complete."
    quit sc
}

ClassMethod RunCase(name As %String, url As %String, method As %String, body As %String, key As %String, expected As %String, ByRef sc As %Status) [ Private ]
{
    set status = "PASS"
    try {
        set json = ..HttpJson(url, method, body)
        if '$isobject(json) {
            set status = "FAIL"
            set sc = $$$ERROR($$$GeneralError, name_" returned non-JSON")
        } else {
            if (expected '= "") && (json.%Get(key)'=expected) {
                set status = "FAIL"
                set sc = $$$ERROR($$$GeneralError, name_" expected "_key_"="_expected_" got "_json.%Get(key))
            }
        }
        write !, "[", status, "] ", name, " -> ", url
        if $isobject(json) {
            write !, "    response: ", $extract(json.%ToJSON(),1,220)
        }
    } catch ex {
        set status = "FAIL"
        set sc = ex.AsStatus()
        write !, "[FAIL] ", name, " -> ", ex.DisplayString()
    }
    quit
}

ClassMethod HttpJson(url As %String, method As %String = "GET", body As %String = "") As %DynamicObject [ Private ]
{
    set req = ##class(%Net.HttpRequest).%New()
    set req.Server = ..ExtractServer(url)
    set req.Port = ..ExtractPort(url)
    set req.Https = ..IsHttps(url)
    set req.SSLConfiguration = ""
    set req.ContentType = "application/json"
    set req.Timeout = 20
    if method="POST" {
        do req.EntityBody.Write(body)
        set sc = req.Post(..ExtractPath(url))
    } else {
        set sc = req.Get(..ExtractPath(url))
    }
    if $$$ISERR(sc) {
        do $system.Status.DecomposeStatus(sc,.errs)
        set msg = $get(errs(1))
        throw ##class(%Exception.General).%New("HTTP request failed: "_msg)
    }
    set rsp = req.HttpResponse
    set txt = rsp.Data.Read()
    if rsp.StatusCode<200 || rsp.StatusCode>299 {
        throw ##class(%Exception.General).%New("HTTP "_rsp.StatusCode_": "_$extract(txt,1,240))
    }
    quit ##class(%DynamicObject).%FromJSON(txt)
}

ClassMethod IsHttps(url As %String) As %Boolean [ Private ]
{
    quit ($extract(url,1,8)="https://")
}

ClassMethod ExtractServer(url As %String) As %String [ Private ]
{
    set u = $piece(url,"://",2,*)
    set hp = $piece(u,"/",1)
    quit $piece(hp,":",1)
}

ClassMethod ExtractPort(url As %String) As %Integer [ Private ]
{
    set u = $piece(url,"://",2,*)
    set hp = $piece(u,"/",1)
    set p = $piece(hp,":",2)
    if p="" quit $select(..IsHttps(url):443,1:80)
    quit +p
}

ClassMethod ExtractPath(url As %String) As %String [ Private ]
{
    set u = $piece(url,"://",2,*)
    set p = $piece(u,"/",2,*)
    quit "/"_p
}

}
