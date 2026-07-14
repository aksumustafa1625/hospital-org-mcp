trigger AppointmentTrigger on Appointment__c (before insert, before update) {
    new AppointmentTriggerHandler().run();
}