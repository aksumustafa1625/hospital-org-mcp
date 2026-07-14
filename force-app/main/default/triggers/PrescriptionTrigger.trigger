trigger PrescriptionTrigger on Prescription__c (before insert) {
    new PrescriptionTriggerHandler().run();
}