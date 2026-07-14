/**
 * @description  Unit tests for ApexTestRunner. The Tooling runTestsSynchronous callout is mocked,
 *               so tests run offline. Covers an all-pass run with coverage, a run with a failure,
 *               and an HTTP-error response.
 *
 * @group        DevOps / Tooling
 * @author       Mustafa Aksu
 * @since        2026
 */
@isTest
private class ApexTestRunnerTest {

    /** @description Mock returning a canned runTestsSynchronous result. */
    private class RunMock implements HttpCalloutMock {
        Integer status;
        String body;
        RunMock(Integer status, String body) { this.status = status; this.body = body; }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(status);
            res.setBody(body);
            return res;
        }
    }

    private static ApexTestRunner.TestRequest sampleRequest() {
        ApexTestRunner.TestRequest r = new ApexTestRunner.TestRequest();
        r.testClassNames = 'FooTest, BarTest';
        return r;
    }

    @isTest
    static void reportsPassAndCoverage() {
        String body = JSON.serialize(new Map<String, Object>{
            'numTestsRun' => 4, 'numFailures' => 0,
            'codeCoverage' => new List<Object>{
                new Map<String, Object>{ 'name' => 'Foo', 'numLocations' => 100, 'numLocationsNotCovered' => 5 }
            }
        });
        Test.setMock(HttpCalloutMock.class, new RunMock(200, body));
        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            ApexTestRunner.run(new List<ApexTestRunner.TestRequest>{ sampleRequest() });
        Test.stopTest();

        System.assertEquals(true, out[0].success, 'All-pass run should be success');
        System.assert(out[0].message.contains('95%'), 'Coverage percent should be computed');
    }

    @isTest
    static void reportsFailure() {
        String body = JSON.serialize(new Map<String, Object>{
            'numTestsRun' => 2, 'numFailures' => 1,
            'failures' => new List<Object>{
                new Map<String, Object>{ 'name' => 'Foo', 'methodName' => 'testX', 'message' => 'assert failed' }
            }
        });
        Test.setMock(HttpCalloutMock.class, new RunMock(200, body));
        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            ApexTestRunner.run(new List<ApexTestRunner.TestRequest>{ sampleRequest() });
        Test.stopTest();

        System.assertEquals(false, out[0].success, 'A failure should make the run unsuccessful');
        System.assert(out[0].message.contains('assert failed'), 'Failure detail should surface');
    }

    @isTest
    static void reportsHttpError() {
        Test.setMock(HttpCalloutMock.class, new RunMock(400, '[{"message":"bad request"}]'));
        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            ApexTestRunner.run(new List<ApexTestRunner.TestRequest>{ sampleRequest() });
        Test.stopTest();

        System.assertEquals(false, out[0].success, 'HTTP error should be reported as failure');
    }
}