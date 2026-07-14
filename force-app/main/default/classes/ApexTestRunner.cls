/**
 * @description  Runs Apex tests synchronously via the Tooling API and reports the outcome —
 *               pass/fail counts, any failure details, and per-class code coverage. Exposed as an
 *               MCP tool so a conversational client can prove its generated tests pass and that
 *               coverage clears the bar, right after deploying them. Auth is delegated to the
 *               'SelfDeploy' Named Credential, same as ApexClassDeployer.
 *
 * @group        DevOps / Tooling
 * @author       Mustafa Aksu
 * @since        2026
 */
global with sharing class ApexTestRunner {

    /** Base path for Tooling REST calls through the Named Credential. */
    private static final String TOOLING_BASE = 'callout:SelfDeploy/services/data/v63.0/tooling';

    /**
     * @description Request wrapper naming the test classes to run in one synchronous run.
     */
    global class TestRequest {
        @InvocableVariable(required=true label='Test Class Names'
            description='Comma-separated Apex test class names, e.g. AppointmentTriggerHandlerTest,AdmissionTriggerHandlerTest')
        global String testClassNames;
    }

    /**
     * @description Invocable entry point. Runs the named test classes and reports results.
     * @param  requests  List of test-run requests (Salesforce passes a bulk list).
     * @return List of results, index-aligned with the input list.
     */
    @InvocableMethod(label='Run Apex Tests'
        description='Runs Apex tests synchronously via the Tooling API and reports pass/fail counts and per-class code coverage.'
        callout=true)
    global static List<ApexClassDeployer.DeployResult> run(List<TestRequest> requests) {
        List<ApexClassDeployer.DeployResult> results = new List<ApexClassDeployer.DeployResult>();
        for (TestRequest req : requests) {
            results.add(runSingle(req));
        }
        return results;
    }

    /** @description Submits one synchronous test run and formats the outcome. */
    private static ApexClassDeployer.DeployResult runSingle(TestRequest req) {
        ApexClassDeployer.DeployResult res = new ApexClassDeployer.DeployResult();
        try {
            List<Object> tests = new List<Object>();
            for (String c : req.testClassNames.split(',')) {
                if (String.isNotBlank(c)) {
                    tests.add(new Map<String, Object>{ 'className' => c.trim() });
                }
            }
            HttpRequest r = new HttpRequest();
            r.setEndpoint(TOOLING_BASE + '/runTestsSynchronous/');
            r.setMethod('POST');
            r.setHeader('Content-Type', 'application/json');
            r.setTimeout(120000);
            r.setBody(JSON.serialize(new Map<String, Object>{ 'tests' => tests, 'maxFailedTests' => -1 }));
            HttpResponse resp = new Http().send(r);
            res = parse(resp);
        } catch (Exception e) {
            res.success = false;
            res.message = 'Test run failed: ' + e.getMessage();
        }
        return res;
    }

    /** @description Turns the Tooling test result into a success flag and a readable summary. */
    private static ApexClassDeployer.DeployResult parse(HttpResponse resp) {
        ApexClassDeployer.DeployResult res = new ApexClassDeployer.DeployResult();
        if (resp.getStatusCode() < 200 || resp.getStatusCode() >= 300) {
            res.success = false;
            res.message = 'Tooling API error (' + resp.getStatusCode() + '): ' + resp.getBody();
            return res;
        }
        Map<String, Object> b = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
        Integer numRun  = toInt(b.get('numTestsRun'));
        Integer numFail = toInt(b.get('numFailures'));
        String msg = 'Ran ' + numRun + ' tests: ' + (numRun - numFail) + ' passed, ' + numFail + ' failed.';

        List<Object> fails = (List<Object>) b.get('failures');
        if (fails != null) {
            for (Object o : fails) {
                Map<String, Object> f = (Map<String, Object>) o;
                msg += '\nFAIL ' + f.get('name') + '.' + f.get('methodName') + ': ' + f.get('message');
            }
        }

        List<Object> cov = (List<Object>) b.get('codeCoverage');
        if (cov != null && !cov.isEmpty()) {
            msg += '\nCoverage:';
            for (Object o : cov) {
                Map<String, Object> c = (Map<String, Object>) o;
                Integer loc    = toInt(c.get('numLocations'));
                Integer notCov = toInt(c.get('numLocationsNotCovered'));
                Integer pct    = loc > 0 ? ((loc - notCov) * 100) / loc : 100;
                msg += '\n  ' + c.get('name') + ': ' + pct + '%';
            }
        }

        res.success = (numFail == 0);
        res.message = msg;
        return res;
    }

    /** @description Null-safe Object→Integer coercion for JSON numbers. */
    private static Integer toInt(Object o) {
        return o == null ? 0 : Integer.valueOf(String.valueOf(o));
    }
}