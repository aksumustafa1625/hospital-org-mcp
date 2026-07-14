/**
 * @description Handles Prescription__c automations: only allows prescriptions on Completed appointments.
 * @group Hospital
 * @author Mustafa Aksu
 * @since 2026
 */
public with sharing class PrescriptionTriggerHandler extends TriggerHandler {

    private List<Prescription__c> newList;

    public PrescriptionTriggerHandler() {
        this.newList = (List<Prescription__c>) Trigger.new;
    }

    public override void beforeInsert() {
        validateAppointmentCompleted(this.newList);
    }

    private void validateAppointmentCompleted(List<Prescription__c> scripts) {
        Set<Id> apptIds = new Set<Id>();
        for (Prescription__c p : scripts) {
            if (p.Appointment__c != null) {
                apptIds.add(p.Appointment__c);
            }
        }

        Map<Id, Appointment__c> apptById = new Map<Id, Appointment__c>([
            SELECT Id, Status__c FROM Appointment__c WHERE Id IN :apptIds
        ]);

        for (Prescription__c p : scripts) {
            if (p.Appointment__c == null) {
                p.addError('A prescription must be linked to an appointment.');
                continue;
            }
            Appointment__c appt = apptById.get(p.Appointment__c);
            if (appt == null || appt.Status__c != 'Completed') {
                p.addError('Prescriptions can only be added to appointments with status Completed.');
            }
        }
    }
}