/**
 * @description Handles Admission__c automations: syncs Room availability with admission status.
 * @group Hospital
 * @author Mustafa Aksu
 * @since 2026
 */
public with sharing class AdmissionTriggerHandler extends TriggerHandler {

    private List<Admission__c> newList;

    public AdmissionTriggerHandler() {
        this.newList = (List<Admission__c>) Trigger.new;
    }

    public override void afterInsert() {
        syncRoomAvailability(this.newList);
    }

    public override void afterUpdate() {
        syncRoomAvailability(this.newList);
    }

    private void syncRoomAvailability(List<Admission__c> admissions) {
        Map<Id, Boolean> roomAvailability = new Map<Id, Boolean>();
        for (Admission__c a : admissions) {
            if (a.Room__c == null || String.isBlank(a.Status__c)) {
                continue;
            }
            if (a.Status__c == 'Admitted') {
                roomAvailability.put(a.Room__c, false);
            } else if (a.Status__c == 'Discharged') {
                // Only free the room if no other active admission holds it
                roomAvailability.put(a.Room__c, true);
            }
        }
        if (roomAvailability.isEmpty()) {
            return;
        }

        // Guard: a room being discharged should stay occupied if another admission is still Admitted
        Set<Id> roomIds = roomAvailability.keySet();
        Set<Id> stillOccupied = new Set<Id>();
        for (Admission__c a : [
            SELECT Id, Room__c, Status__c FROM Admission__c
            WHERE Room__c IN :roomIds AND Status__c = 'Admitted'
        ]) {
            stillOccupied.add(a.Room__c);
        }

        List<Room__c> roomsToUpdate = new List<Room__c>();
        for (Id roomId : roomAvailability.keySet()) {
            Boolean available = roomAvailability.get(roomId);
            if (available && stillOccupied.contains(roomId)) {
                available = false; // keep occupied
            }
            roomsToUpdate.add(new Room__c(Id = roomId, IsAvailable__c = available));
        }
        if (!roomsToUpdate.isEmpty()) {
            update roomsToUpdate;
        }
    }
}