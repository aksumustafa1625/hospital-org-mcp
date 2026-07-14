/**
 * @description  Inserts records into any object from a JSON array, coercing each value to the
 *               field's real type. Exposed as an MCP tool so a conversational client can seed demo
 *               data (sample doctors, patients, rooms, appointments) after the data model and Apex
 *               are in place — leaving the org populated and ready to show.
 *
 * @group        DevOps / Tooling
 * @author       Mustafa Aksu
 * @since        2026
 */
global with sharing class RecordCreator {

    /** @description One insert request: an object and a JSON array of records for it. */
    global class RecordRequest {
        @InvocableVariable(required=true label='Object API Name'
            description='API name of the object to insert into, e.g. Doctor__c')
        global String objectApiName;

        @InvocableVariable(required=true label='Records JSON'
            description='JSON array of records; each record is a map of field API name to value.')
        global String recordsJson;
    }

    /**
     * @description Invocable entry point. Inserts the records for each request and reports how many
     *              landed. Runs in user mode via "with sharing" so FLS/CRUD still apply.
     * @param  requests  List of insert requests (Salesforce passes a bulk list).
     * @return List of results, index-aligned with the input list.
     */
    @InvocableMethod(label='Create Records'
        description='Inserts one or more records into an object from JSON. Use to seed demo data.')
    global static List<ApexClassDeployer.DeployResult> create(List<RecordRequest> requests) {
        List<ApexClassDeployer.DeployResult> results = new List<ApexClassDeployer.DeployResult>();
        for (RecordRequest req : requests) {
            results.add(createSingle(req));
        }
        return results;
    }

    /** @description Builds typed sObjects from the JSON and inserts them in one DML call. */
    private static ApexClassDeployer.DeployResult createSingle(RecordRequest req) {
        ApexClassDeployer.DeployResult res = new ApexClassDeployer.DeployResult();
        try {
            Schema.SObjectType t = Schema.getGlobalDescribe().get(req.objectApiName);
            if (t == null) {
                throw new RecordException('Unknown object: ' + req.objectApiName);
            }
            Map<String, Schema.SObjectField> fieldMap = t.getDescribe().fields.getMap();

            List<SObject> toInsert = new List<SObject>();
            for (Object o : (List<Object>) JSON.deserializeUntyped(req.recordsJson)) {
                Map<String, Object> row = (Map<String, Object>) o;
                SObject rec = t.newSObject();
                for (String f : row.keySet()) {
                    Schema.SObjectField sf = fieldMap.get(f);
                    if (sf == null) {
                        throw new RecordException('Unknown field "' + f + '" on ' + req.objectApiName);
                    }
                    rec.put(f, coerce(row.get(f), sf.getDescribe().getType()));
                }
                toInsert.add(rec);
            }
            insert toInsert;
            List<String> ids = new List<String>();
            for (SObject rec : toInsert) {
                ids.add(String.valueOf(rec.get('Id')));
            }
            res.success = true;
            res.message = 'Inserted ' + toInsert.size() + ' ' + req.objectApiName
                + ' record(s). Ids: ' + String.join(ids, ', ');
        } catch (Exception e) {
            res.success = false;
            res.message = 'Insert failed for ' + req.objectApiName + ': ' + e.getMessage();
        }
        return res;
    }

    /** @description Coerces a JSON value to the target field's Apex type. */
    private static Object coerce(Object v, Schema.DisplayType dt) {
        if (v == null) return null;
        String s = String.valueOf(v);
        if (dt == Schema.DisplayType.DATE)     return Date.valueOf(s);
        if (dt == Schema.DisplayType.DATETIME) return DateTime.valueOf(s.replace('T', ' '));
        if (dt == Schema.DisplayType.DOUBLE || dt == Schema.DisplayType.CURRENCY || dt == Schema.DisplayType.PERCENT) {
            return Decimal.valueOf(s);
        }
        if (dt == Schema.DisplayType.INTEGER || dt == Schema.DisplayType.LONG) return Integer.valueOf(s);
        if (dt == Schema.DisplayType.BOOLEAN) return Boolean.valueOf(s);
        return s;
    }

    /** @description Custom exception for record-creation failures. */
    global class RecordException extends Exception {}
}