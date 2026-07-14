/**
 * @description  Unit tests for MetadataObjectDeployer. The Metadata API SOAP callout is mocked, so
 *               tests run offline. Covers a successful object+fields create and a SOAP-fault path,
 *               and exercises each supported field type through the envelope builder.
 *
 * @group        DevOps / Tooling
 * @author       Mustafa Aksu
 * @since        2026
 */
@isTest
private class MetadataObjectDeployerTest {

    /** @description Mock returning either a success result or a SOAP fault. */
    private class MdApiMock implements HttpCalloutMock {
        Boolean ok;
        MdApiMock(Boolean ok) { this.ok = ok; }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'text/xml');
            if (ok) {
                res.setStatusCode(200);
                res.setBody('<soapenv:Envelope><soapenv:Body><createMetadataResponse><result>'
                    + '<fullName>Patient__c</fullName><success>true</success></result>'
                    + '</createMetadataResponse></soapenv:Body></soapenv:Envelope>');
            } else {
                res.setStatusCode(500);
                res.setBody('<soapenv:Envelope><soapenv:Body><soapenv:Fault>'
                    + '<faultstring>INVALID_TYPE: bad metadata</faultstring>'
                    + '</soapenv:Fault></soapenv:Body></soapenv:Envelope>');
            }
            return res;
        }
    }

    /** @description Object request exercising every supported field type. */
    private static MetadataObjectDeployer.ObjectRequest sampleRequest() {
        MetadataObjectDeployer.ObjectRequest r = new MetadataObjectDeployer.ObjectRequest();
        r.objectApiName = 'Patient__c';
        r.label = 'Patient';
        r.pluralLabel = 'Patients';
        r.fieldsJson = JSON.serialize(new List<Object>{
            new Map<String, Object>{ 'fullName' => 'Age__c', 'label' => 'Age', 'type' => 'Number', 'precision' => 3, 'scale' => 0 },
            new Map<String, Object>{ 'fullName' => 'Fee__c', 'label' => 'Fee', 'type' => 'Currency' },
            new Map<String, Object>{ 'fullName' => 'Bio__c', 'label' => 'Bio', 'type' => 'LongTextArea', 'length' => 5000, 'visibleLines' => 3 },
            new Map<String, Object>{ 'fullName' => 'Active__c', 'label' => 'Active', 'type' => 'Checkbox' },
            new Map<String, Object>{ 'fullName' => 'AdmitDate__c', 'label' => 'Admit Date', 'type' => 'Date', 'required' => true },
            new Map<String, Object>{ 'fullName' => 'Email__c', 'label' => 'Email', 'type' => 'Email' },
            new Map<String, Object>{ 'fullName' => 'Notes__c', 'label' => 'Notes', 'type' => 'Text', 'length' => 120 },
            new Map<String, Object>{ 'fullName' => 'Gender__c', 'label' => 'Gender', 'type' => 'Picklist', 'values' => new List<Object>{ 'Male', 'Female', 'Other' } },
            new Map<String, Object>{ 'fullName' => 'Doctor__c', 'label' => 'Doctor', 'type' => 'Lookup', 'referenceTo' => 'Doctor__c', 'relationshipName' => 'Patients', 'relationshipLabel' => 'Patients' }
        });
        return r;
    }

    @isTest
    static void createsObjectWithFields() {
        Test.setMock(HttpCalloutMock.class, new MdApiMock(true));
        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            MetadataObjectDeployer.deploy(new List<MetadataObjectDeployer.ObjectRequest>{ sampleRequest() });
        Test.stopTest();

        System.assertEquals(1, out.size(), 'One result expected');
        System.assertEquals(true, out[0].success, 'Object create should succeed');
    }

    @isTest
    static void reportsSoapFault() {
        Test.setMock(HttpCalloutMock.class, new MdApiMock(false));
        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            MetadataObjectDeployer.deploy(new List<MetadataObjectDeployer.ObjectRequest>{ sampleRequest() });
        Test.stopTest();

        System.assertEquals(false, out[0].success, 'SOAP fault should be reported as failure');
        System.assert(out[0].message.contains('INVALID_TYPE'), 'Fault detail should surface');
    }

    @isTest
    static void handlesObjectWithoutFields() {
        MetadataObjectDeployer.ObjectRequest r = new MetadataObjectDeployer.ObjectRequest();
        r.objectApiName = 'Room__c';
        r.label = 'Room';
        r.pluralLabel = 'Rooms';
        Test.setMock(HttpCalloutMock.class, new MdApiMock(true));
        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            MetadataObjectDeployer.deploy(new List<MetadataObjectDeployer.ObjectRequest>{ r });
        Test.stopTest();

        System.assertEquals(true, out[0].success, 'Object without fields should still succeed');
    }
}