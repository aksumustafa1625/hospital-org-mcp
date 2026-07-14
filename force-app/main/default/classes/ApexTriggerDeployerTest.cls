/**
 * @description  Unit tests for ApexTriggerDeployer and the trigger-deployment logic in
 *               ApexClassDeployer.runTriggerDeploys. All Tooling API callouts are mocked, so the
 *               tests run offline. Covers create (direct ApexTrigger POST), update (container +
 *               ApexTriggerMember + async), a compilation-failure path, and an HTTP-error path.
 *
 * @group        DevOps / Tooling
 * @author       Mustafa Aksu
 * @since        2026
 */
@isTest
private class ApexTriggerDeployerTest {

    /**
     * @description Configurable mock returning canned responses per request path, pointed at a
     *              'Completed'/'Failed' async outcome, an existing/absent trigger, or an error.
     */
    private class ToolingMock implements HttpCalloutMock {
        String finalState;      // State returned for ContainerAsyncRequest polling
        Boolean triggerExists;  // Whether the query for an existing trigger returns a record
        Boolean httpError;      // Force a non-2xx on the create/container call

        ToolingMock(String finalState, Boolean triggerExists, Boolean httpError) {
            this.finalState    = finalState;
            this.triggerExists = triggerExists;
            this.httpError     = httpError;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/query')) {
                // Existing-trigger lookup.
                List<Object> records = triggerExists
                    ? new List<Object>{ new Map<String, Object>{ 'Id' => '01qXX0000000001' } }
                    : new List<Object>();
                res.setStatusCode(200);
                res.setBody(JSON.serialize(new Map<String, Object>{ 'records' => records }));
            } else if (endpoint.contains('ApexTriggerMember')) {
                res.setStatusCode(201);
                res.setBody('{"id":"400XX0000000001"}');
            } else if (endpoint.endsWith('/sobjects/ApexTrigger') && req.getMethod() == 'POST') {
                // Direct create of a brand-new trigger.
                if (httpError || finalState == 'Failed') {
                    res.setStatusCode(400);
                    res.setBody('[{"message":"line 1: syntax error"}]');
                } else {
                    res.setStatusCode(201);
                    res.setBody('{"id":"01qXX0000000002"}');
                }
            } else if (endpoint.contains('MetadataContainer') && req.getMethod() == 'POST') {
                if (httpError) {
                    res.setStatusCode(400);
                    res.setBody('[{"message":"bad container"}]');
                } else {
                    res.setStatusCode(201);
                    res.setBody('{"id":"1drXX0000000001"}');
                }
            } else if (endpoint.contains('ContainerAsyncRequest') && req.getMethod() == 'POST') {
                res.setStatusCode(201);
                res.setBody('{"id":"1dcXX0000000001"}');
            } else if (endpoint.contains('ContainerAsyncRequest') && req.getMethod() == 'GET') {
                res.setStatusCode(200);
                res.setBody(JSON.serialize(new Map<String, Object>{
                    'State'    => finalState,
                    'ErrorMsg' => (finalState == 'Failed') ? 'line 1: syntax error' : null
                }));
            } else {
                // DELETE cleanup and any fallthrough.
                res.setStatusCode(204);
                res.setBody('');
            }
            return res;
        }
    }

    /** @description Builds a valid trigger deploy request for reuse across tests. */
    private static ApexClassDeployer.DeployTriggerRequest sampleTriggerRequest() {
        ApexClassDeployer.DeployTriggerRequest r = new ApexClassDeployer.DeployTriggerRequest();
        r.triggerName = 'AccountTrigger';
        r.sObjectName = 'Account';
        r.triggerBody = 'trigger AccountTrigger on Account (before insert) { new AccountTriggerHandler().run(); }';
        return r;
    }

    @isTest
    static void deploysNewTriggerSuccessfully() {
        Test.setMock(HttpCalloutMock.class, new ToolingMock('Completed', false, false));
        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            ApexTriggerDeployer.deploy(new List<ApexClassDeployer.DeployTriggerRequest>{ sampleTriggerRequest() });
        Test.stopTest();

        System.assertEquals(1, out.size(), 'One result expected');
        System.assertEquals(true, out[0].success, 'New trigger deploy should succeed');
    }

    @isTest
    static void updatesExistingTriggerSuccessfully() {
        Test.setMock(HttpCalloutMock.class, new ToolingMock('Completed', true, false));
        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            ApexTriggerDeployer.deploy(new List<ApexClassDeployer.DeployTriggerRequest>{ sampleTriggerRequest() });
        Test.stopTest();

        System.assertEquals(true, out[0].success, 'Existing trigger update should succeed');
    }

    @isTest
    static void reportsCompilationFailureOnCreate() {
        Test.setMock(HttpCalloutMock.class, new ToolingMock('Failed', false, false));
        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            ApexTriggerDeployer.deploy(new List<ApexClassDeployer.DeployTriggerRequest>{ sampleTriggerRequest() });
        Test.stopTest();

        System.assertEquals(false, out[0].success, 'Failed trigger compilation should be reported');
        System.assert(out[0].message.contains('syntax error'), 'Error detail should surface');
    }

    @isTest
    static void reportsCompilationFailureOnUpdate() {
        Test.setMock(HttpCalloutMock.class, new ToolingMock('Failed', true, false));
        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            ApexTriggerDeployer.deploy(new List<ApexClassDeployer.DeployTriggerRequest>{ sampleTriggerRequest() });
        Test.stopTest();

        System.assertEquals(false, out[0].success, 'Failed async compilation should be reported');
        System.assert(out[0].message.contains('syntax error'), 'Error detail should surface');
    }

    @isTest
    static void reportsHttpError() {
        // Existing-trigger path with a non-2xx on container creation exercises the error throw.
        Test.setMock(HttpCalloutMock.class, new ToolingMock('Completed', true, true));
        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            ApexTriggerDeployer.deploy(new List<ApexClassDeployer.DeployTriggerRequest>{ sampleTriggerRequest() });
        Test.stopTest();

        System.assertEquals(false, out[0].success, 'HTTP error should be reported as failure');
    }
}