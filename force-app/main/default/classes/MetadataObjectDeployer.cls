/**
 * @description  Creates a custom object (with its fields) in this org at runtime via the SOAP
 *               Metadata API. The Tooling API used by ApexClassDeployer/ApexTriggerDeployer cannot
 *               create schema, so this class fills that gap: exposed as an MCP tool, it lets a
 *               conversational client build a whole data model — objects, fields, relationships —
 *               before deploying the Apex that runs on top of it.
 *
 *               Authentication uses the running user's session (UserInfo.getSessionId()) placed in
 *               the SOAP SessionHeader; the callout targets the org's own My Domain, allowed by the
 *               SelfMetadataApi Remote Site Setting. Developer / Sandbox / Scratch orgs only.
 *
 * @group        DevOps / Tooling
 * @author       Mustafa Aksu
 * @since        2026
 */
global with sharing class MetadataObjectDeployer {

    /** Metadata API SOAP endpoint, reached through the SelfDeploy Named Credential. */
    private static final String MDAPI_ENDPOINT = 'callout:SelfDeploy/services/Soap/m/63.0';

    /**
     * @description Request wrapper for one custom object. Fields are supplied as a JSON array so a
     *              single call can build the object and all of its columns at once.
     */
    global class ObjectRequest {
        @InvocableVariable(required=true label='Object API Name'
            description='API name of the custom object, e.g. Patient__c')
        global String objectApiName;

        @InvocableVariable(required=true label='Label'
            description='Singular label, e.g. Patient')
        global String label;

        @InvocableVariable(required=true label='Plural Label'
            description='Plural label, e.g. Patients')
        global String pluralLabel;

        @InvocableVariable(label='Fields JSON'
            description='Optional JSON array of field definitions, each with fullName, label, type and type-specific keys (length, precision, scale, values, referenceTo, relationshipName, relationshipLabel).')
        global String fieldsJson;
    }

    /**
     * @description Invocable entry point. Creates each requested custom object (with fields) and
     *              reports the outcome. Reuses ApexClassDeployer.DeployResult for a consistent shape.
     * @param  requests  List of object requests (Salesforce passes a bulk list).
     * @return List of results, index-aligned with the input list.
     */
    @InvocableMethod(label='Deploy Custom Object'
        description='Creates a custom object and its fields in this org via the Metadata API.'
        callout=true)
    global static List<ApexClassDeployer.DeployResult> deploy(List<ObjectRequest> requests) {
        List<ApexClassDeployer.DeployResult> results = new List<ApexClassDeployer.DeployResult>();
        for (ObjectRequest req : requests) {
            results.add(deploySingle(req));
        }
        return results;
    }

    /** @description Builds the SOAP envelope, calls createMetadata, and interprets the response. */
    private static ApexClassDeployer.DeployResult deploySingle(ObjectRequest req) {
        ApexClassDeployer.DeployResult res = new ApexClassDeployer.DeployResult();
        try {
            warmToken();
            HttpRequest r = new HttpRequest();
            r.setEndpoint(MDAPI_ENDPOINT);
            r.setMethod('POST');
            r.setHeader('Content-Type', 'text/xml; charset=UTF-8');
            r.setHeader('SOAPAction', '""');
            r.setTimeout(120000);
            r.setBody(buildEnvelope(req));
            HttpResponse resp = new Http().send(r);
            res = parseResult(resp, req.objectApiName);
        } catch (Exception e) {
            res.success = false;
            res.message = 'Deploy failed for ' + req.objectApiName + ': ' + e.getMessage();
        }
        return res;
    }

    /**
     * @description Makes a lightweight Tooling GET through the Named Credential so it refreshes its
     *              stored OAuth token. The Metadata API reads the token from the SOAP SessionHeader
     *              via the {!$Credential.OAuthToken} merge field, which must be current — and unlike
     *              the auto-refreshed Authorization header, the stored token can otherwise be stale.
     *              This is what makes the tool work when invoked via MCP (an API context where
     *              UserInfo.getSessionId() is not a usable Metadata API session).
     */
    private static void warmToken() {
        HttpRequest ping = new HttpRequest();
        ping.setEndpoint('callout:SelfDeploy/services/data/v63.0/tooling/sobjects/ApexClass/describe');
        ping.setMethod('GET');
        new Http().send(ping);
    }

    /** @description Assembles the full createMetadata SOAP request for a CustomObject with fields. */
    private static String buildEnvelope(ObjectRequest req) {
        String fieldsXml = '';
        if (String.isNotBlank(req.fieldsJson)) {
            for (Object o : (List<Object>) JSON.deserializeUntyped(req.fieldsJson)) {
                fieldsXml += buildFieldXml((Map<String, Object>) o);
            }
        }
        return '<?xml version="1.0" encoding="UTF-8"?>'
            + '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'
            + ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
            + ' xmlns="http://soap.sforce.com/2006/04/metadata">'
            +   '<soapenv:Header><SessionHeader><sessionId>{!$Credential.OAuthToken}</sessionId></SessionHeader></soapenv:Header>'
            +   '<soapenv:Body>'
            +     '<createMetadata>'
            +       '<metadata xsi:type="CustomObject">'
            +         '<fullName>' + esc(req.objectApiName) + '</fullName>'
            +         '<label>' + esc(req.label) + '</label>'
            +         '<pluralLabel>' + esc(req.pluralLabel) + '</pluralLabel>'
            +         '<nameField><type>Text</type><label>' + esc(req.label) + ' Name</label></nameField>'
            +         '<deploymentStatus>Deployed</deploymentStatus>'
            +         '<sharingModel>ReadWrite</sharingModel>'
            +         fieldsXml
            +       '</metadata>'
            +     '</createMetadata>'
            +   '</soapenv:Body>'
            + '</soapenv:Envelope>';
    }

    /** @description Builds the <fields> XML for one field definition, keyed off its "type". */
    private static String buildFieldXml(Map<String, Object> f) {
        String type = (String) f.get('type');
        String api  = esc((String) f.get('fullName'));
        String lbl  = esc((String) f.get('label'));
        String x = '<fields><fullName>' + api + '</fullName><label>' + lbl + '</label><type>' + esc(type) + '</type>';

        if (type == 'Text' || type == 'TextArea') {
            if (type == 'Text') x += '<length>' + numOr(f.get('length'), 255) + '</length>';
        } else if (type == 'LongTextArea' || type == 'Html') {
            x += '<length>' + numOr(f.get('length'), 32768) + '</length>';
            x += '<visibleLines>' + numOr(f.get('visibleLines'), 3) + '</visibleLines>';
        } else if (type == 'Number' || type == 'Currency' || type == 'Percent') {
            x += '<precision>' + numOr(f.get('precision'), 18) + '</precision>';
            x += '<scale>' + numOr(f.get('scale'), 0) + '</scale>';
        } else if (type == 'Picklist') {
            x += buildPicklist(f);
        } else if (type == 'Lookup' || type == 'MasterDetail') {
            x += '<referenceTo>' + esc((String) f.get('referenceTo')) + '</referenceTo>';
            x += '<relationshipLabel>' + esc((String) f.get('relationshipLabel')) + '</relationshipLabel>';
            x += '<relationshipName>' + esc((String) f.get('relationshipName')) + '</relationshipName>';
        }
        // MasterDetail is implicitly required; for the rest honor an explicit "required" flag.
        if (type != 'MasterDetail' && type != 'Checkbox' && f.get('required') == true) {
            x += '<required>true</required>';
        }
        if (type == 'Checkbox') {
            x += '<defaultValue>false</defaultValue>';
        }
        return x + '</fields>';
    }

    /** @description Builds a Picklist valueSet from a JSON "values" array. */
    private static String buildPicklist(Map<String, Object> f) {
        String vals = '';
        for (Object v : (List<Object>) f.get('values')) {
            String s = esc(String.valueOf(v));
            vals += '<value><fullName>' + s + '</fullName><default>false</default><label>' + s + '</label></value>';
        }
        return '<valueSet><valueSetDefinition><sorted>false</sorted>' + vals + '</valueSetDefinition></valueSet>';
    }

    /** @description Interprets the SOAP response: looks for success, else surfaces the error text. */
    private static ApexClassDeployer.DeployResult parseResult(HttpResponse resp, String objectName) {
        ApexClassDeployer.DeployResult res = new ApexClassDeployer.DeployResult();
        String body = resp.getBody();
        if (body != null && body.contains('<success>true</success>')) {
            res.success = true;
            res.message = 'Deployed ' + objectName + ' successfully.';
        } else {
            res.success = false;
            res.message = 'Deploy failed for ' + objectName + ': ' + extract(body);
        }
        return res;
    }

    /** @description Pulls the most useful error text out of a SOAP fault / result body. */
    private static String extract(String body) {
        if (body == null) return 'empty response';
        String tag = firstTag(body, 'faultstring');
        if (tag != null) return tag;
        tag = firstTag(body, 'message');
        if (tag != null) return tag;
        tag = firstTag(body, 'statusCode');
        return tag != null ? tag : body.abbreviate(500);
    }

    /** @description Returns the text inside the first <tag>…</tag>, or null if absent. */
    private static String firstTag(String body, String tag) {
        Integer a = body.indexOf('<' + tag + '>');
        Integer b = body.indexOf('</' + tag + '>');
        return (a >= 0 && b > a) ? body.substring(a + tag.length() + 2, b) : null;
    }

    /** @description Coerces a JSON number (or null) to an Integer string with a fallback. */
    private static String numOr(Object v, Integer fallback) {
        return String.valueOf(v == null ? fallback : (Integer) Double.valueOf(String.valueOf(v)));
    }

    /** @description Escapes XML special characters. */
    private static String esc(String s) {
        if (s == null) return '';
        return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
                .replace('"', '&quot;').replace('\'', '&apos;');
    }
}