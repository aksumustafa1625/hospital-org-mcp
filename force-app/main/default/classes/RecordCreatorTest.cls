/**
 * @description  Unit tests for RecordCreator. Uses the standard Account object so the tests run in
 *               any org. Covers a successful multi-record insert with type coercion, and an
 *               unknown-field error path.
 *
 * @group        DevOps / Tooling
 * @author       Mustafa Aksu
 * @since        2026
 */
@isTest
private class RecordCreatorTest {

    @isTest
    static void insertsRecordsWithCoercion() {
        RecordCreator.RecordRequest r = new RecordCreator.RecordRequest();
        r.objectApiName = 'Account';
        r.recordsJson = JSON.serialize(new List<Object>{
            new Map<String, Object>{ 'Name' => 'Alpha Clinic', 'NumberOfEmployees' => 50 },
            new Map<String, Object>{ 'Name' => 'Beta Clinic' }
        });

        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            RecordCreator.create(new List<RecordCreator.RecordRequest>{ r });
        Test.stopTest();

        System.assertEquals(true, out[0].success, 'Insert should succeed');
        System.assertEquals(2, [SELECT COUNT() FROM Account WHERE Name LIKE '%Clinic'], 'Both records should land');
    }

    @isTest
    static void reportsUnknownField() {
        RecordCreator.RecordRequest r = new RecordCreator.RecordRequest();
        r.objectApiName = 'Account';
        r.recordsJson = JSON.serialize(new List<Object>{
            new Map<String, Object>{ 'Name' => 'X', 'NotAReal__c' => 'oops' }
        });

        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            RecordCreator.create(new List<RecordCreator.RecordRequest>{ r });
        Test.stopTest();

        System.assertEquals(false, out[0].success, 'Unknown field should fail');
        System.assert(out[0].message.contains('Unknown field'), 'Error detail should surface');
    }

    @isTest
    static void reportsUnknownObject() {
        RecordCreator.RecordRequest r = new RecordCreator.RecordRequest();
        r.objectApiName = 'NotAnObject__c';
        r.recordsJson = '[{"Name":"X"}]';

        Test.startTest();
        List<ApexClassDeployer.DeployResult> out =
            RecordCreator.create(new List<RecordCreator.RecordRequest>{ r });
        Test.stopTest();

        System.assertEquals(false, out[0].success, 'Unknown object should fail');
    }
}