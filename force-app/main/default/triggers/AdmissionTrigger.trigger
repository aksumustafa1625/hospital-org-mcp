trigger AdmissionTrigger on Admission__c (after insert, after update) {
    new AdmissionTriggerHandler().run();
}