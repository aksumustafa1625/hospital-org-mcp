/**
 * @description  Unit tests for AppBuilder. The Metadata API createMetadata callouts are mocked, so
 *               tests run offline. Covers a full success path and a SOAP-fault path.
 *
 * @group        DevOps / Tooling
 * @author       Mustafa Aksu
 * @since        2026
 */
@isTest
private class AppBuilderTest {

    /** @description Mock returning a createMetadata success or a SOAP fault for every call. */
    private class MdApiMock implements HttpCalloutMock {
        Boolean ok;
        MdApiMock(Boolean ok) { this.ok = ok; }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'text/xml');
            if (ok) {
                res.setStatusCode(200);
                res.setBody('<soapenv:Envelope><soapenv:Body><createMetadataResponse><result>'
                    + '<success>true</success></result></createMetadataResponse></soapenv:Body></soapenv:Envelope>');
            } else {
                res.setStatusCode(500);
                res.setBody('<soapenv:Envelope><soapenv:Body><soapenv:Fault>'
                    + '<faultstring>INVALID_TYPE: bad metadata</faultstring></soapenv:Fault></soapenv:Body></soapenv:Envelope>');
            }
            return res;
        }
    }

    private static AppBuilder.AppRequest sampleRequest() {
        // Standard objects so the describe works in any org (the tool discovers fields via describe).
        AppBuilder.AppRequest r = new AppBuilder.AppRequest();
        r.appApiName = 'Sample_App';
        r.appLabel = 'Sample App';
        r.objectApiNames = 'Account, Contact';
        return r;
    }

    @isTest
    static void buildsAppSuccessfully() {
        Test.setMock(HttpCalloutMock.class, new MdApiMock(true));
        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            AppBuilder.deploy(new List<AppBuilder.AppRequest>{ sampleRequest() });
        Test.stopTest();

        System.assertEquals(1, out.size(), 'One result expected');
        System.assertEquals(true, out[0].success, 'App build should succeed');
        System.assert(out[0].message.contains('2 objects'), 'Should report object count');
    }

    @isTest
    static void reportsSoapFault() {
        Test.setMock(HttpCalloutMock.class, new MdApiMock(false));
        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            AppBuilder.deploy(new List<AppBuilder.AppRequest>{ sampleRequest() });
        Test.stopTest();

        System.assertEquals(false, out[0].success, 'A SOAP fault should be reported as failure');
        System.assert(out[0].message.contains('INVALID_TYPE'), 'Fault detail should surface');
    }
}