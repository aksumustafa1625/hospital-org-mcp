/**
 * @description Tests double-booking prevention and status defaulting for Appointment__c.
 * @group Hospital
 * @author Mustafa Aksu
 * @since 2026
 */
@isTest
private class AppointmentTriggerHandlerTest {

    @testSetup
    static void setup() {
        Department__c dept = new Department__c(Name = 'Cardiology Dept', Location__c = 'Wing A');
        insert dept;
        Doctor__c doc = new Doctor__c(Name = 'Dr. Heart', Specialty__c = 'Cardiology', Department__c = dept.Id);
        insert doc;
        Patient__c pat = new Patient__c(Name = 'John Doe', Age__c = 40, Gender__c = 'Male');
        insert pat;
    }

    @isTest
    static void testStatusDefaultAndValidInsert() {
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];
        Patient__c pat = [SELECT Id FROM Patient__c LIMIT 1];
        Datetime slot = Datetime.newInstance(2026, 6, 1, 9, 0, 0);

        Appointment__c a = new Appointment__c(
            Doctor__c = doc.Id, Patient__c = pat.Id, AppointmentDateTime__c = slot, Reason__c = 'Checkup'
        );
        Test.startTest();
        insert a;
        Test.stopTest();

        Appointment__c inserted = [SELECT Status__c FROM Appointment__c WHERE Id = :a.Id];
        System.assertEquals('Scheduled', inserted.Status__c, 'Blank status should default to Scheduled');
    }

    @isTest
    static void testDoubleBookingBlocked() {
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];
        Patient__c pat = [SELECT Id FROM Patient__c LIMIT 1];
        Datetime slot = Datetime.newInstance(2026, 6, 1, 10, 0, 0);

        insert new Appointment__c(Doctor__c = doc.Id, Patient__c = pat.Id, AppointmentDateTime__c = slot, Status__c = 'Scheduled');

        Appointment__c dupe = new Appointment__c(Doctor__c = doc.Id, Patient__c = pat.Id, AppointmentDateTime__c = slot, Status__c = 'Scheduled');
        Boolean blocked = false;
        Test.startTest();
        try {
            insert dupe;
        } catch (DmlException e) {
            blocked = true;
            System.assert(e.getMessage().contains('already booked'), 'Should block with double-booking message');
        }
        Test.stopTest();
        System.assert(blocked, 'Double-booking should be blocked');
    }

    @isTest
    static void testCancelledSlotAllowed() {
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];
        Patient__c pat = [SELECT Id FROM Patient__c LIMIT 1];
        Datetime slot = Datetime.newInstance(2026, 6, 1, 11, 0, 0);

        insert new Appointment__c(Doctor__c = doc.Id, Patient__c = pat.Id, AppointmentDateTime__c = slot, Status__c = 'Cancelled');

        Appointment__c ok = new Appointment__c(Doctor__c = doc.Id, Patient__c = pat.Id, AppointmentDateTime__c = slot, Status__c = 'Scheduled');
        Test.startTest();
        insert ok;
        Test.stopTest();
        System.assertNotEquals(null, ok.Id, 'Should allow booking a slot whose only conflict is Cancelled');
    }
}