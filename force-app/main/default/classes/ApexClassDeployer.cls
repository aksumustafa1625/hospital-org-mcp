/**
 * @description  Deploys (creates or updates) Apex classes into this org at runtime via the
 *               Tooling API, using the MetadataContainer / ApexClassMember / ContainerAsyncRequest
 *               pattern. Exposed as an Invocable action so it can be called as an MCP tool from a
 *               conversational client (e.g. Claude). Intended for Developer / Sandbox / Scratch orgs
 *               only — the Tooling API cannot create Apex in production.
 *
 *               Authentication is delegated to the 'SelfDeploy' Named Credential, so no session id or
 *               secret is ever handled in code.
 *
 * @group        DevOps / Tooling
 * @author       Mustafa Aksu
 * @since        2026
 */
global with sharing class ApexClassDeployer {

    /** Base path appended to the Named Credential endpoint for all Tooling REST calls. */
    private static final String TOOLING_BASE = 'callout:SelfDeploy/services/data/v63.0/tooling';

    /**
     * @description Request wrapper for a single class deployment. One Apex class per invocation.
     */
    global class DeployRequest {
        @InvocableVariable(required=true label='Class Name'
            description='API name of the Apex class, e.g. AccountTriggerHandler')
        global String className;

        @InvocableVariable(required=true label='Class Body'
            description='Full source of the Apex class, including the class declaration.')
        global String classBody;
    }

    /**
     * @description Request wrapper for a single trigger deployment. One Apex trigger per
     *              invocation. Under the Kevin O'Hara framework the body should be a thin
     *              one-liner delegating to a handler, e.g.
     *              'trigger InstallationTrigger on Installation__c (before insert, after update)
     *               { new InstallationTriggerHandler().run(); }'.
     */
    global class DeployTriggerRequest {
        @InvocableVariable(required=true label='Trigger Name'
            description='API name of the Apex trigger, e.g. InstallationTrigger')
        global String triggerName;

        @InvocableVariable(required=true label='SObject Name'
            description='API name of the SObject the trigger runs on, e.g. Account or Installation__c')
        global String sObjectName;

        @InvocableVariable(required=true label='Trigger Body'
            description='Full source of the Apex trigger, including the trigger declaration.')
        global String triggerBody;
    }

    /**
     * @description Result wrapper returned to the caller.
     */
    global class DeployResult {
        @InvocableVariable global Boolean success;
        @InvocableVariable global String  message;
    }

    /**
     * @description Invocable entry point. Deploys each requested class and reports the outcome.
     *              Because callouts are involved, this cannot run inside a trigger context.
     * @param  requests  List of class deployment requests (Salesforce passes a bulk list).
     * @return List of results, index-aligned with the input list.
     */
    @InvocableMethod(label='Deploy Apex Class'
        description='Creates or updates an Apex class in this org via the Tooling API.'
        callout=true)
    global static List<DeployResult> deploy(List<DeployRequest> requests) {
        List<DeployResult> results = new List<DeployResult>();
        for (DeployRequest req : requests) {
            results.add(deploySingle(req));
        }
        return results;
    }

    /**
     * @description Entry point for trigger deployment. Deploys each requested trigger and
     *              reports the outcome. Exposed to callers via the thin ApexTriggerDeployer
     *              invocable wrapper — a class may declare only one @InvocableMethod, so the
     *              trigger action lives in its own class while the logic stays here.
     * @param  requests  List of trigger deployment requests.
     * @return List of results, index-aligned with the input list.
     */
    public static List<DeployResult> runTriggerDeploys(List<DeployTriggerRequest> requests) {
        List<DeployResult> results = new List<DeployResult>();
        for (DeployTriggerRequest req : requests) {
            results.add(deploySingleTrigger(req));
        }
        return results;
    }

    /**
     * @description Handles the full deploy lifecycle for one class:
     *              1) create a MetadataContainer
     *              2) add an ApexClassMember carrying the new/updated body
     *              3) submit a ContainerAsyncRequest and poll until compilation finishes
     *              4) clean up the container
     * @param  req  the single deploy request
     * @return a populated DeployResult
     */
    private static DeployResult deploySingle(DeployRequest req) {
        DeployResult res = new DeployResult();
        String containerId;
        try {
            // 1) Look up an existing class to decide between create and update.
            String existingId = findClassId(req.className);

            // 2a) New class: the Tooling API creates it with a direct, synchronous POST
            //     to the ApexClass sobject. The MetadataContainer/ApexClassMember pattern
            //     only works for updates — ApexClassMember requires an existing
            //     ContentEntityId, so it 500s for a class that does not exist yet.
            if (existingId == null) {
                return createClass(req);
            }

            // 2b) Existing class: use the container/member/async pattern to update the body.
            containerId = createContainer('Deploy_' + req.className + '_' + Datetime.now().getTime());
            addClassMember(containerId, existingId, req.classBody);

            // Submit for asynchronous compilation and wait for the verdict.
            String asyncId = submitContainer(containerId);
            res = pollAsyncRequest(asyncId, req.className);
        } catch (Exception e) {
            res.success = false;
            res.message = 'Deploy failed for ' + req.className + ': ' + e.getMessage();
        } finally {
            // Best-effort cleanup so containers don't accumulate in the org.
            if (containerId != null) {
                deleteContainer(containerId);
            }
        }
        return res;
    }

    /**
     * @description Creates a brand-new Apex class via a direct POST to the Tooling API's
     *              ApexClass sobject. Compilation is synchronous for this call, so the
     *              outcome — including any compile error in the response body — is known
     *              immediately, without a container or async polling.
     * @param  req  the deploy request for a class that does not yet exist
     * @return a populated DeployResult
     */
    private static DeployResult createClass(DeployRequest req) {
        DeployResult res = new DeployResult();
        // The class name is derived from the body, so only Body is sent.
        HttpResponse r = doCall('POST', '/sobjects/ApexClass',
            JSON.serialize(new Map<String, Object>{ 'Body' => req.classBody }));
        if (r.getStatusCode() >= 200 && r.getStatusCode() < 300) {
            res.success = true;
            res.message = 'Deployed ' + req.className + ' successfully.';
        } else {
            res.success = false;
            res.message = 'Compilation failed for ' + req.className + ': ' + r.getBody();
        }
        return res;
    }

    /**
     * @description Trigger counterpart of deploySingle. Mirrors the class flow but targets the
     *              ApexTrigger / ApexTriggerMember sobjects:
     *              - new trigger  -> direct, synchronous POST to ApexTrigger
     *              - existing one -> MetadataContainer + ApexTriggerMember + async compile
     * @param  req  the single trigger deploy request
     * @return a populated DeployResult
     */
    private static DeployResult deploySingleTrigger(DeployTriggerRequest req) {
        DeployResult res = new DeployResult();
        String containerId;
        try {
            // 1) Look up an existing trigger to decide between create and update.
            String existingId = findTriggerId(req.triggerName);

            // 2a) New trigger: created with a direct POST. ApexTrigger needs the target
            //     SObject (TableEnumOrId), unlike ApexClass whose name comes from the body.
            if (existingId == null) {
                return createTrigger(req);
            }

            // 2b) Existing trigger: container/member/async pattern to update the body.
            containerId = createContainer('Deploy_' + req.triggerName + '_' + Datetime.now().getTime());
            addTriggerMember(containerId, existingId, req.triggerBody);

            String asyncId = submitContainer(containerId);
            res = pollAsyncRequest(asyncId, req.triggerName);
        } catch (Exception e) {
            res.success = false;
            res.message = 'Deploy failed for ' + req.triggerName + ': ' + e.getMessage();
        } finally {
            if (containerId != null) {
                deleteContainer(containerId);
            }
        }
        return res;
    }

    /**
     * @description Creates a brand-new Apex trigger via a direct POST to the ApexTrigger
     *              sobject. Name and TableEnumOrId are supplied explicitly (the API requires
     *              them for triggers) alongside the full body.
     * @param  req  the deploy request for a trigger that does not yet exist
     * @return a populated DeployResult
     */
    private static DeployResult createTrigger(DeployTriggerRequest req) {
        DeployResult res = new DeployResult();
        HttpResponse r = doCall('POST', '/sobjects/ApexTrigger',
            JSON.serialize(new Map<String, Object>{
                'Name'          => req.triggerName,
                'TableEnumOrId' => req.sObjectName,
                'Body'          => req.triggerBody
            }));
        if (r.getStatusCode() >= 200 && r.getStatusCode() < 300) {
            res.success = true;
            res.message = 'Deployed ' + req.triggerName + ' successfully.';
        } else {
            res.success = false;
            res.message = 'Compilation failed for ' + req.triggerName + ': ' + r.getBody();
        }
        return res;
    }

    /** @description Returns the Id of an existing ApexTrigger by name, or null if not present. */
    private static String findTriggerId(String triggerName) {
        String soql = 'SELECT Id FROM ApexTrigger WHERE Name = \'' + String.escapeSingleQuotes(triggerName) + '\'';
        HttpResponse r = doCall('GET', '/query/?q=' + EncodingUtil.urlEncode(soql, 'UTF-8'), null);
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(r.getBody());
        List<Object> records = (List<Object>) body.get('records');
        if (records != null && !records.isEmpty()) {
            return (String) ((Map<String, Object>) records[0]).get('Id');
        }
        return null;
    }

    /** @description Adds an ApexTriggerMember (the trigger body) to the container for an update. */
    private static void addTriggerMember(String containerId, String existingTriggerId, String body) {
        HttpResponse r = doCall('POST', '/sobjects/ApexTriggerMember', JSON.serialize(new Map<String, Object>{
            'MetadataContainerId' => containerId,
            'ContentEntityId'     => existingTriggerId,
            'Body'                => body
        }));
        parseId(r, 'ApexTriggerMember creation');
    }

    /** @description Creates a MetadataContainer and returns its Id. */
    private static String createContainer(String name) {
        HttpResponse r = doCall('POST', '/sobjects/MetadataContainer',
            JSON.serialize(new Map<String, Object>{ 'Name' => name.left(32) }));
        return (String) parseId(r, 'MetadataContainer creation');
    }

    /** @description Returns the Id of an existing ApexClass by name, or null if not present. */
    private static String findClassId(String className) {
        String soql = 'SELECT Id FROM ApexClass WHERE Name = \'' + String.escapeSingleQuotes(className) + '\'';
        HttpResponse r = doCall('GET', '/query/?q=' + EncodingUtil.urlEncode(soql, 'UTF-8'), null);
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(r.getBody());
        List<Object> records = (List<Object>) body.get('records');
        if (records != null && !records.isEmpty()) {
            return (String) ((Map<String, Object>) records[0]).get('Id');
        }
        return null;
    }

    /** @description Adds an ApexClassMember (the actual body) to the container. */
    private static void addClassMember(String containerId, String existingClassId, String body) {
        Map<String, Object> payload = new Map<String, Object>{
            'MetadataContainerId' => containerId,
            'Body'                => body
        };
        // If the class already exists, reference it so this is treated as an update.
        if (existingClassId != null) {
            payload.put('ContentEntityId', existingClassId);
        }
        HttpResponse r = doCall('POST', '/sobjects/ApexClassMember', JSON.serialize(payload));
        parseId(r, 'ApexClassMember creation');
    }

    /** @description Submits the container for compilation, returns the ContainerAsyncRequest Id. */
    private static String submitContainer(String containerId) {
        HttpResponse r = doCall('POST', '/sobjects/ContainerAsyncRequest',
            JSON.serialize(new Map<String, Object>{
                'MetadataContainerId' => containerId,
                'IsCheckOnly'         => false
            }));
        return (String) parseId(r, 'ContainerAsyncRequest submission');
    }

    /**
     * @description Polls the async request until it leaves the 'Queued' state, then interprets
     *              the outcome. Uses short bounded waits to stay within callout limits.
     */
    private static DeployResult pollAsyncRequest(String asyncId, String className) {
        DeployResult res = new DeployResult();
        String state = 'Queued';
        Integer attempts = 0;
        Map<String, Object> record;

        while ((state == 'Queued') && attempts < 10) {
            // Small busy-wait; Tooling compilation of a single class is typically fast.
            Long target = Datetime.now().getTime() + 1000;
            while (Datetime.now().getTime() < target) { /* wait ~1s */ }

            HttpResponse r = doCall('GET',
                '/sobjects/ContainerAsyncRequest/' + asyncId, null);
            record = (Map<String, Object>) JSON.deserializeUntyped(r.getBody());
            state = (String) record.get('State');
            attempts++;
        }

        if (state == 'Completed') {
            res.success = true;
            res.message = 'Deployed ' + className + ' successfully.';
        } else if (state == 'Failed' || state == 'Error') {
            res.success = false;
            res.message = 'Compilation failed for ' + className + ': '
                + String.valueOf(record.get('ErrorMsg'));
        } else {
            res.success = false;
            res.message = 'Deploy of ' + className + ' did not complete in time (state=' + state + ').';
        }
        return res;
    }

    /** @description Deletes a MetadataContainer to clean up after a deploy. */
    private static void deleteContainer(String containerId) {
        try {
            doCall('DELETE', '/sobjects/MetadataContainer/' + containerId, null);
        } catch (Exception ignored) {
            // Cleanup is best-effort; never mask the primary result with a cleanup error.
        }
    }

    /**
     * @description Central HTTP helper for all Tooling REST calls through the Named Credential.
     * @param  method    HTTP verb
     * @param  path      path relative to the Tooling base
     * @param  bodyJson  request body, or null for GET/DELETE
     * @return the HttpResponse
     */
    private static HttpResponse doCall(String method, String path, String bodyJson) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(TOOLING_BASE + path);
        req.setMethod(method);
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);
        if (bodyJson != null) {
            req.setBody(bodyJson);
        }
        return new Http().send(req);
    }

    /**
     * @description Extracts the 'id' field from a create response, or throws with context if the
     *              call did not succeed.
     */
    private static Object parseId(HttpResponse r, String context) {
        if (r.getStatusCode() >= 200 && r.getStatusCode() < 300) {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(r.getBody());
            return body.get('id');
        }
        throw new DeployException(context + ' failed (' + r.getStatusCode() + '): ' + r.getBody());
    }

    /** @description Custom exception for deploy failures. */
    public class DeployException extends Exception {}
}