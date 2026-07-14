/**
 * @description Tests that prescriptions are only allowed on Completed appointments.
 * @group Hospital
 * @author Mustafa Aksu
 * @since 2026
 */
@isTest
private class PrescriptionTriggerHandlerTest {

    @testSetup
    static void setup() {
        Department__c dept = new Department__c(Name = 'General Dept', Location__c = 'Wing B');
        insert dept;
        Doctor__c doc = new Doctor__c(Name = 'Dr. Gen', Specialty__c = 'General', Department__c = dept.Id);
        insert doc;
        Patient__c pat = new Patient__c(Name = 'Jane Roe', Age__c = 30, Gender__c = 'Female');
        insert pat;
    }

    @isTest
    static void testPrescriptionAllowedOnCompleted() {
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];
        Patient__c pat = [SELECT Id FROM Patient__c LIMIT 1];
        Appointment__c appt = new Appointment__c(
            Doctor__c = doc.Id, Patient__c = pat.Id,
            AppointmentDateTime__c = Datetime.newInstance(2026, 6, 2, 9, 0, 0),
            Status__c = 'Completed'
        );
        insert appt;

        Prescription__c p = new Prescription__c(Medication__c = 'Aspirin', Dosage__c = '100mg', Appointment__c = appt.Id);
        Test.startTest();
        insert p;
        Test.stopTest();
        System.assertNotEquals(null, p.Id, 'Prescription should be allowed on Completed appointment');
    }

    @isTest
    static void testPrescriptionBlockedOnScheduled() {
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];
        Patient__c pat = [SELECT Id FROM Patient__c LIMIT 1];
        Appointment__c appt = new Appointment__c(
            Doctor__c = doc.Id, Patient__c = pat.Id,
            AppointmentDateTime__c = Datetime.newInstance(2026, 6, 2, 10, 0, 0),
            Status__c = 'Scheduled'
        );
        insert appt;

        Prescription__c p = new Prescription__c(Medication__c = 'Ibuprofen', Dosage__c = '200mg', Appointment__c = appt.Id);
        Boolean blocked = false;
        Test.startTest();
        try {
            insert p;
        } catch (DmlException e) {
            blocked = true;
            System.assert(e.getMessage().contains('Completed'), 'Should block with Completed-status message');
        }
        Test.stopTest();
        System.assert(blocked, 'Prescription on non-Completed appointment should be blocked');
    }

    @isTest
    static void testPrescriptionBlockedWhenNoAppointment() {
        Prescription__c p = new Prescription__c(Medication__c = 'Paracetamol', Dosage__c = '500mg');
        Boolean blocked = false;
        Test.startTest();
        try {
            insert p;
        } catch (DmlException e) {
            blocked = true;
            System.assert(e.getMessage().contains('linked to an appointment'), 'Should block prescription with no appointment');
        }
        Test.stopTest();
        System.assert(blocked, 'Prescription with no appointment should be blocked');
    }
}