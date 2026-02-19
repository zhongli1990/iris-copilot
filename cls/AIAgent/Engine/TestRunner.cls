/// Core engine: Executes %UnitTest suites and returns structured results.
/// 
/// Part of the IRIS AI Agent Platform (IRIS Copilot).
Class AIAgent.Engine.TestRunner [ Abstract ]
{

/// Run a specific test class and return results as JSON.
ClassMethod RunTestClass(testClassName As %String) As %DynamicObject
{
    set result = ##class(%DynamicObject).%New()
    set result.testClass = testClassName
    set methods = ##class(%DynamicArray).%New()
    set passCount = 0
    set failCount = 0
    set errorCount = 0
    try {
        // Verify the test class exists and is a %UnitTest.TestCase
        if '##class(%Dictionary.ClassDefinition).%ExistsId(testClassName) {
            set result.error = "Test class '"_testClassName_"' does not exist"
            return result
        }

        // Get all Test* methods from the class
        set sql = "SELECT Name FROM %Dictionary.MethodDefinition WHERE parent = ? AND Name LIKE 'Test%'"
        set stmt = ##class(%SQL.Statement).%New()
        do stmt.%Prepare(sql)
        set rs = stmt.%Execute(testClassName)

        while rs.%Next() {
            set methodName = rs.%GetData(1)
            set methodResult = ##class(%DynamicObject).%New()
            set methodResult.name = methodName

            try {
                // Create test instance and run the method
                set testObj = $classmethod(testClassName, "%New")
                do $method(testObj, methodName)

                // If we got here without exception, the method passed
                set methodResult.status = "passed"
                set passCount = passCount + 1
            } catch testEx {
                // Check if it's an assertion failure or a real error
                if testEx.Name [ "AssertFailure" {
                    set methodResult.status = "failed"
                    set methodResult.message = testEx.DisplayString()
                    set failCount = failCount + 1
                } else {
                    set methodResult.status = "error"
                    set methodResult.message = testEx.DisplayString()
                    set errorCount = errorCount + 1
                }
            }

            do methods.%Push(methodResult)
        }
    } catch ex {
        set result.error = "Test runner error: "_ex.DisplayString()
        set errorCount = errorCount + 1
    }

    set result.methods = methods
    set result.passed = passCount
    set result.failed = failCount
    set result.errors = errorCount
    set result.total = passCount + failCount + errorCount
    set result.success = (failCount = 0) && (errorCount = 0)

    // Audit
    if result.success {
        do ##class(AIAgent.Model.AuditEntry).LogSuccess("test", testClassName, passCount_" passed")
    } else {
        do ##class(AIAgent.Model.AuditEntry).LogFailure("test", testClassName, failCount_" failed, "_errorCount_" errors")
    }

    return result
}

/// Run all test classes matching a pattern (e.g., "AIAgent.Generated.%.Test.%").
ClassMethod RunTestSuite(pattern As %String = "AIAgent.Generated.%.Test.%") As %DynamicObject
{
    set result = ##class(%DynamicObject).%New()
    set result.pattern = pattern
    set classes = ##class(%DynamicArray).%New()
    set totalPassed = 0
    set totalFailed = 0
    set totalErrors = 0

    // Find all test classes matching the pattern
    set sql = "SELECT Name FROM %Dictionary.ClassDefinition WHERE Name LIKE ? AND (Super [ '%UnitTest.TestCase' OR Super [ 'AIAgent')"
    set stmt = ##class(%SQL.Statement).%New()
    do stmt.%Prepare(sql)
    set rs = stmt.%Execute(pattern)

    while rs.%Next() {
        set testClass = rs.%GetData(1)
        set classResult = ..RunTestClass(testClass)
        do classes.%Push(classResult)
        set totalPassed = totalPassed + classResult.passed
        set totalFailed = totalFailed + classResult.failed
        set totalErrors = totalErrors + classResult.errors
    }

    set result.classes = classes
    set result.totalPassed = totalPassed
    set result.totalFailed = totalFailed
    set result.totalErrors = totalErrors
    set result.totalTests = totalPassed + totalFailed + totalErrors
    set result.success = (totalFailed = 0) && (totalErrors = 0)

    return result
}

/// Send a test HL7 message into a Business Service.
/// Returns the message header ID for tracing.
ClassMethod SendTestMessage(serviceName As %String, hl7Content As %String) As %DynamicObject
{
    set result = ##class(%DynamicObject).%New()
    try {
        // Create an HL7 message from the content string
        set msg = ##class(EnsLib.HL7.Message).%New()
        // Parse the HL7 content
        set sc = msg.ImportFromString(hl7Content)
        if $$$ISERR(sc) {
            set result.error = "Failed to parse HL7: "_$system.Status.GetOneErrorText(sc)
            return result
        }

        // Create a business service instance and process the message
        set sc = ##class(Ens.Director).CreateBusinessService(serviceName, .service)
        if $$$ISERR(sc) {
            set result.error = "Failed to create service '"_serviceName_"': "_$system.Status.GetOneErrorText(sc)
            return result
        }

        set sc = service.ProcessInput(msg)
        if $$$ISOK(sc) {
            set result.success = 1
            set result.message = "Test message sent to "_serviceName
        } else {
            set result.success = 0
            set result.error = $system.Status.GetOneErrorText(sc)
        }
    } catch ex {
        set result.error = ex.DisplayString()
    }
    return result
}

}
