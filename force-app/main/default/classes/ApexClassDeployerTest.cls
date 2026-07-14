/**
 * @description  Unit tests for ApexClassDeployer. All Tooling API callouts are mocked, so these
 *               tests run offline and never touch a real endpoint. Covers the happy path
 *               (create + update), a compilation-failure path, and an HTTP-error path.
 *
 * @group        DevOps / Tooling
 * @author       Mustafa Aksu
 * @since        2026
 */
@isTest
private class ApexClassDeployerTest {

    /**
     * @description Configurable mock that returns canned responses based on the request path,
     *              and can be pointed at a 'Completed', 'Failed', or error scenario.
     */
    private class ToolingMock implements HttpCalloutMock {
        String finalState;      // State returned for ContainerAsyncRequest polling
        Boolean classExists;    // Whether the query for an existing class returns a record
        Boolean httpError;      // Force a non-2xx on container creation

        ToolingMock(String finalState, Boolean classExists, Boolean httpError) {
            this.finalState  = finalState;
            this.classExists = classExists;
            this.httpError   = httpError;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/query')) {
                // Existing-class lookup.
                List<Object> records = classExists
                    ? new List<Object>{ new Map<String, Object>{ 'Id' => '01pXX0000000001' } }
                    : new List<Object>();
                res.setStatusCode(200);
                res.setBody(JSON.serialize(new Map<String, Object>{ 'records' => records }));
            } else if (endpoint.contains('ApexClassMember') || endpoint.contains('ApexTriggerMember')) {
                // Must be checked before the generic ApexClass/ApexTrigger branches below.
                res.setStatusCode(201);
                res.setBody('{"id":"400XX0000000001"}');
            } else if (endpoint.endsWith('/sobjects/ApexClass') && req.getMethod() == 'POST') {
                // Direct create of a brand-new class.
                if (httpError || finalState == 'Failed') {
                    res.setStatusCode(400);
                    res.setBody('[{"message":"line 1: syntax error"}]');
                } else {
                    res.setStatusCode(201);
                    res.setBody('{"id":"01pXX0000000002"}');
                }
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

    /** @description Builds a valid deploy request for reuse across tests. */
    private static ApexClassDeployer.DeployRequest sampleRequest() {
        ApexClassDeployer.DeployRequest r = new ApexClassDeployer.DeployRequest();
        r.className = 'HelloWorld';
        r.classBody = 'public class HelloWorld { public String hi() { return \'hi\'; } }';
        return r;
    }

    @isTest
    static void deploysNewClassSuccessfully() {
        Test.setMock(HttpCalloutMock.class, new ToolingMock('Completed', false, false));
        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            ApexClassDeployer.deploy(new List<ApexClassDeployer.DeployRequest>{ sampleRequest() });
        Test.stopTest();

        System.assertEquals(1, out.size(), 'One result expected');
        System.assertEquals(true, out[0].success, 'New class deploy should succeed');
    }

    @isTest
    static void updatesExistingClassSuccessfully() {
        Test.setMock(HttpCalloutMock.class, new ToolingMock('Completed', true, false));
        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            ApexClassDeployer.deploy(new List<ApexClassDeployer.DeployRequest>{ sampleRequest() });
        Test.stopTest();

        System.assertEquals(true, out[0].success, 'Existing class update should succeed');
    }

    @isTest
    static void reportsCompilationFailureOnCreate() {
        // New class whose body fails to compile: the direct ApexClass POST returns the error.
        Test.setMock(HttpCalloutMock.class, new ToolingMock('Failed', false, false));
        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            ApexClassDeployer.deploy(new List<ApexClassDeployer.DeployRequest>{ sampleRequest() });
        Test.stopTest();

        System.assertEquals(false, out[0].success, 'Failed compilation should be reported');
        System.assert(out[0].message.contains('syntax error'), 'Error detail should surface');
    }

    @isTest
    static void reportsCompilationFailureOnUpdate() {
        // Existing class update that fails compilation: the async request reports 'Failed'.
        Test.setMock(HttpCalloutMock.class, new ToolingMock('Failed', true, false));
        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            ApexClassDeployer.deploy(new List<ApexClassDeployer.DeployRequest>{ sampleRequest() });
        Test.stopTest();

        System.assertEquals(false, out[0].success, 'Failed async compilation should be reported');
        System.assert(out[0].message.contains('syntax error'), 'Error detail should surface');
    }

    @isTest
    static void reportsHttpError() {
        // Existing-class path with a non-2xx on container creation exercises the error throw.
        Test.setMock(HttpCalloutMock.class, new ToolingMock('Completed', true, true));
        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            ApexClassDeployer.deploy(new List<ApexClassDeployer.DeployRequest>{ sampleRequest() });
        Test.stopTest();

        System.assertEquals(false, out[0].success, 'HTTP error should be reported as failure');
    }
}