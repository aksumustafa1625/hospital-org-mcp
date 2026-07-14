/**
 * @description Handles Appointment__c automations: prevents double-booking and defaults Status.
 * @group Hospital
 * @author Mustafa Aksu
 * @since 2026
 */
public with sharing class AppointmentTriggerHandler extends TriggerHandler {

    private List<Appointment__c> newList;
    private Map<Id, Appointment__c> oldMap;

    public AppointmentTriggerHandler() {
        this.newList = (List<Appointment__c>) Trigger.new;
        this.oldMap = (Map<Id, Appointment__c>) Trigger.oldMap;
    }

    public override void beforeInsert() {
        defaultStatus(this.newList);
        preventDoubleBooking(this.newList);
    }

    public override void beforeUpdate() {
        preventDoubleBooking(this.newList);
    }

    private void defaultStatus(List<Appointment__c> appts) {
        for (Appointment__c a : appts) {
            if (String.isBlank(a.Status__c)) {
                a.Status__c = 'Scheduled';
            }
        }
    }

    private void preventDoubleBooking(List<Appointment__c> appts) {
        Set<Id> doctorIds = new Set<Id>();
        Set<Datetime> slots = new Set<Datetime>();
        for (Appointment__c a : appts) {
            if (a.Doctor__c != null && a.AppointmentDateTime__c != null && a.Status__c != 'Cancelled') {
                doctorIds.add(a.Doctor__c);
                slots.add(a.AppointmentDateTime__c);
            }
        }
        if (doctorIds.isEmpty()) {
            return;
        }

        // Existing appointments that could conflict
        Map<String, Id> existing = new Map<String, Id>();
        for (Appointment__c e : [
            SELECT Id, Doctor__c, AppointmentDateTime__c, Status__c
            FROM Appointment__c
            WHERE Doctor__c IN :doctorIds
              AND AppointmentDateTime__c IN :slots
              AND Status__c != 'Cancelled'
        ]) {
            existing.put(e.Doctor__c + '|' + String.valueOf(e.AppointmentDateTime__c), e.Id);
        }

        // Track within-batch collisions too
        Map<String, Integer> batchCount = new Map<String, Integer>();

        for (Appointment__c a : appts) {
            if (a.Doctor__c == null || a.AppointmentDateTime__c == null || a.Status__c == 'Cancelled') {
                continue;
            }
            String key = a.Doctor__c + '|' + String.valueOf(a.AppointmentDateTime__c);

            Id conflictId = existing.get(key);
            Boolean dbConflict = (conflictId != null && conflictId != a.Id);

            Integer seen = batchCount.containsKey(key) ? batchCount.get(key) : 0;
            Boolean batchConflict = (seen > 0);
            batchCount.put(key, seen + 1);

            if (dbConflict || batchConflict) {
                a.addError('This doctor is already booked at the selected date and time. Please choose a different slot.');
            }
        }
    }
}