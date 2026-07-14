/**
 * @description Tests that room availability syncs with admission status.
 * @group Hospital
 * @author Mustafa Aksu
 * @since 2026
 */
@isTest
private class AdmissionTriggerHandlerTest {

    @testSetup
    static void setup() {
        Department__c dept = new Department__c(Name = 'Ward Dept', Location__c = 'Wing C');
        insert dept;
        Patient__c pat = new Patient__c(Name = 'Sam Smith', Age__c = 55, Gender__c = 'Male');
        insert pat;
        Room__c room = new Room__c(Name = 'Room 101', RoomType__c = 'ICU', IsAvailable__c = true, Department__c = dept.Id);
        insert room;
    }

    @isTest
    static void testAdmittedMarksRoomUnavailable() {
        Patient__c pat = [SELECT Id FROM Patient__c LIMIT 1];
        Room__c room = [SELECT Id FROM Room__c LIMIT 1];
        Admission__c adm = new Admission__c(
            Patient__c = pat.Id, Room__c = room.Id, Status__c = 'Admitted', AdmitDate__c = Date.newInstance(2026, 6, 1)
        );
        Test.startTest();
        insert adm;
        Test.stopTest();
        Room__c updated = [SELECT IsAvailable__c FROM Room__c WHERE Id = :room.Id];
        System.assertEquals(false, updated.IsAvailable__c, 'Room should be unavailable after admission');
    }

    @isTest
    static void testDischargedMarksRoomAvailable() {
        Patient__c pat = [SELECT Id FROM Patient__c LIMIT 1];
        Room__c room = [SELECT Id FROM Room__c LIMIT 1];
        Admission__c adm = new Admission__c(
            Patient__c = pat.Id, Room__c = room.Id, Status__c = 'Admitted', AdmitDate__c = Date.newInstance(2026, 6, 1)
        );
        insert adm;
        Room__c afterAdmit = [SELECT IsAvailable__c FROM Room__c WHERE Id = :room.Id];
        System.assertEquals(false, afterAdmit.IsAvailable__c, 'Room unavailable after admit');

        adm.Status__c = 'Discharged';
        adm.DischargeDate__c = Date.newInstance(2026, 6, 5);
        Test.startTest();
        update adm;
        Test.stopTest();
        Room__c updated = [SELECT IsAvailable__c FROM Room__c WHERE Id = :room.Id];
        System.assertEquals(true, updated.IsAvailable__c, 'Room should be available after discharge');
    }
}