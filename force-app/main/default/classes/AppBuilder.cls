/**
 * @description  Turns a set of custom objects into a fully browsable Lightning app in one call, via
 *               the SOAP Metadata API. For the given objects it: creates a tab and an "All" list
 *               view each; adds every custom field to each object's page layout; grants field-level
 *               security for those fields; creates the Lightning app over the tabs; and assigns a
 *               permission set (app + tab visibility + FLS) to the running user. Exposed as an MCP
 *               tool so a conversational client can finish a build with a real, usable app — data
 *               visible, records editable — without any manual Setup work.
 *
 *               Metadata-API-created objects don't get FLS, layout fields, tabs, list views, or app
 *               visibility automatically; this tool fills every one of those gaps. Auth mirrors
 *               MetadataObjectDeployer (Named Credential OAuth token in the SOAP SessionHeader,
 *               warmed first), so it works when invoked via MCP. Developer / Sandbox / Scratch only.
 *
 *               NOTE: FLS and layout changes are cached per session — after this runs, log out and
 *               back in (or hard-refresh) before the fields render in the UI.
 *
 * @group        DevOps / Tooling
 * @author       Mustafa Aksu
 * @since        2026
 */
global with sharing class AppBuilder {

    /** Metadata API SOAP endpoint, reached through the SelfDeploy Named Credential. */
    private static final String MDAPI_ENDPOINT = 'callout:SelfDeploy/services/Soap/m/63.0';

    /** @description Request wrapper: one Lightning app over a set of custom objects. */
    global class AppRequest {
        @InvocableVariable(required=true label='App API Name'
            description='API name of the app, e.g. Hospital_Management (letters, numbers, underscores)')
        global String appApiName;

        @InvocableVariable(required=true label='App Label'
            description='Display name of the app, e.g. Hospital Management')
        global String appLabel;

        @InvocableVariable(required=true label='Object API Names'
            description='Comma-separated custom object API names to include, e.g. Patient__c,Doctor__c')
        global String objectApiNames;
    }

    /**
     * @description Invocable entry point. Builds each requested app and reports the outcome.
     * @param  requests  List of app requests (Salesforce passes a bulk list).
     * @return List of results, index-aligned with the input list.
     */
    @InvocableMethod(label='Deploy App'
        description='Creates tabs, list views, page-layout fields, field-level security and a Lightning app so the objects are fully usable in the App Launcher.'
        callout=true)
    global static List<ApexClassDeployer.DeployResult> deploy(List<AppRequest> requests) {
        List<ApexClassDeployer.DeployResult> results = new List<ApexClassDeployer.DeployResult>();
        for (AppRequest req : requests) {
            results.add(deploySingle(req));
        }
        return results;
    }

    /** @description Builds tabs, list views, layouts, FLS, the app and its permission set. */
    private static ApexClassDeployer.DeployResult deploySingle(AppRequest req) {
        ApexClassDeployer.DeployResult res = new ApexClassDeployer.DeployResult();
        try {
            warmToken();
            List<String> objs = new List<String>();
            for (String o : req.objectApiNames.split(',')) {
                if (String.isNotBlank(o)) objs.add(o.trim());
            }

            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            List<String> tabViewItems = new List<String>();
            List<String> layoutItems = new List<String>();
            String fieldPerms = '';

            for (String o : objs) {
                Schema.DescribeSObjectResult d = gd.get(o).getDescribe();

                // Tab + "All" list view.
                tabViewItems.add('<metadata xsi:type="CustomTab"><fullName>' + esc(o) + '</fullName>'
                    + '<customObject>true</customObject><motif>Custom53: Bell</motif></metadata>');
                tabViewItems.add('<metadata xsi:type="ListView"><fullName>' + esc(o) + '.All</fullName>'
                    + '<label>All</label><filterScope>Everything</filterScope><columns>NAME</columns></metadata>');

                // Page layout with every custom field, and FLS for each. Custom fields are read
                // straight from the describe (which lists them regardless of FLS), so we never
                // filter on accessibility — that was the trap that dropped the fields before.
                String col1 = '<layoutItems><behavior>Required</behavior><field>Name</field></layoutItems>';
                String col2 = '';
                Integer i = 0;
                for (String fn : d.fields.getMap().keySet()) {
                    Schema.DescribeFieldResult f = d.fields.getMap().get(fn).getDescribe();
                    if (!f.isCustom()) continue;
                    Boolean calc = f.isCalculated();
                    String item = '<layoutItems><behavior>' + (calc ? 'Readonly' : 'Edit') + '</behavior>'
                        + '<field>' + esc(f.getName()) + '</field></layoutItems>';
                    if (Math.mod(i, 2) == 0) col1 += item; else col2 += item;
                    i++;
                    fieldPerms += '<fieldPermissions><editable>' + (calc ? 'false' : 'true') + '</editable>'
                        + '<field>' + esc(o) + '.' + esc(f.getName()) + '</field><readable>true</readable></fieldPermissions>';
                }
                layoutItems.add('<metadata xsi:type="Layout"><fullName>' + esc(o) + '-' + esc(d.getLabel()) + ' Layout</fullName>'
                    + '<layoutSections><editHeading>true</editHeading><label>Information</label>'
                    + '<layoutColumns>' + col1 + '</layoutColumns><layoutColumns>' + col2 + '</layoutColumns>'
                    + '<style>TwoColumnsTopToBottom</style></layoutSections></metadata>');
            }

            // 1) Tabs + list views (create) — batched to stay within the Metadata API's
            //    limit of 10 components per call (7 objects = 14 tab/list-view components).
            HttpResponse r1 = callBatched('createMetadata', tabViewItems);
            if (!isOk(r1)) { return fail(res, 'Tab/list view creation failed: ' + extract(r1.getBody())); }

            // 2) Layouts (update) — puts the fields on every record's Details and New/Edit form.
            HttpResponse r2 = callBatched('updateMetadata', layoutItems);
            if (!isOk(r2)) { return fail(res, 'Layout update failed: ' + extract(r2.getBody())); }

            // 3) Lightning app (create).
            String tabRefs = '';
            for (String o : objs) tabRefs += '<tabs>' + esc(o) + '</tabs>';
            String app = '<metadata xsi:type="CustomApplication"><fullName>' + esc(req.appApiName) + '</fullName>'
                + '<label>' + esc(req.appLabel) + '</label><uiType>Lightning</uiType><navType>Standard</navType>'
                + '<formFactors>Large</formFactors>' + tabRefs + '</metadata>';
            HttpResponse r3 = callMdApi('createMetadata', app);
            if (!isOk(r3)) { return fail(res, 'App creation failed: ' + extract(r3.getBody())); }

            // 4) Permission set: app visibility + FLS + tab visibility (create), then assign.
            String psName = req.appApiName + '_Access';
            String tabSettings = '';
            for (String o : objs) tabSettings += '<tabSettings><tab>' + esc(o) + '</tab><visibility>Visible</visibility></tabSettings>';
            String ps = '<metadata xsi:type="PermissionSet"><fullName>' + esc(psName) + '</fullName>'
                + '<applicationVisibilities><application>' + esc(req.appApiName) + '</application><visible>true</visible></applicationVisibilities>'
                + fieldPerms
                + '<hasActivationRequired>false</hasActivationRequired>'
                + '<label>' + esc(req.appLabel) + ' Access</label>'
                + tabSettings + '</metadata>';
            HttpResponse r4 = callMdApi('createMetadata', ps);
            if (!isOk(r4)) { return fail(res, 'Permission set creation failed: ' + extract(r4.getBody())); }
            assignPermSet(psName);

            res.success = true;
            res.message = 'Deployed app "' + req.appLabel + '" (' + objs.size() + ' objects) with tabs, '
                + 'list views, layout fields, field-level security and visibility. '
                + 'Log out and back in (or hard-refresh) so the fields render.';
        } catch (Exception e) {
            res.success = false;
            res.message = 'Deploy app failed for ' + req.appLabel + ': ' + e.getMessage();
        }
        return res;
    }

    /** @description Sets a failure result and returns it (keeps the flow readable). */
    private static ApexClassDeployer.DeployResult fail(ApexClassDeployer.DeployResult res, String msg) {
        res.success = false;
        res.message = msg;
        return res;
    }

    /** @description Assigns the visibility/FLS permission set to the running user (idempotent). */
    private static void assignPermSet(String psName) {
        List<PermissionSet> ps = [SELECT Id FROM PermissionSet WHERE Name = :psName LIMIT 1];
        if (ps.isEmpty()) return;
        List<PermissionSetAssignment> existing = [SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSetId = :ps[0].Id];
        if (existing.isEmpty()) {
            insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = ps[0].Id);
        }
    }

    /**
     * @description Sends the given metadata items in batches of at most 10 — the Metadata API
     *              CRUD limit per call. Returns the first failing response, or the last response
     *              if every batch succeeds. Callers check isOk() on the result.
     */
    private static HttpResponse callBatched(String operation, List<String> items) {
        HttpResponse last;
        for (Integer i = 0; i < items.size(); i += 10) {
            List<String> chunk = new List<String>();
            for (Integer j = i; j < Math.min(i + 10, items.size()); j++) {
                chunk.add(items[j]);
            }
            last = callMdApi(operation, String.join(chunk, ''));
            if (!isOk(last)) return last;
        }
        return last;
    }

    /** @description Sends a create/updateMetadata SOAP request wrapping the given <metadata> elements. */
    private static HttpResponse callMdApi(String operation, String metadataXml) {
        String env = '<?xml version="1.0" encoding="UTF-8"?>'
            + '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'
            + ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
            + ' xmlns="http://soap.sforce.com/2006/04/metadata">'
            +   '<soapenv:Header><SessionHeader><sessionId>{!$Credential.OAuthToken}</sessionId></SessionHeader></soapenv:Header>'
            +   '<soapenv:Body><' + operation + '>' + metadataXml + '</' + operation + '></soapenv:Body>'
            + '</soapenv:Envelope>';
        HttpRequest r = new HttpRequest();
        r.setEndpoint(MDAPI_ENDPOINT);
        r.setMethod('POST');
        r.setHeader('Content-Type', 'text/xml; charset=UTF-8');
        r.setHeader('SOAPAction', '""');
        r.setTimeout(120000);
        r.setBody(env);
        return new Http().send(r);
    }

    /** @description Refreshes the Named Credential's stored OAuth token (see MetadataObjectDeployer). */
    private static void warmToken() {
        HttpRequest ping = new HttpRequest();
        ping.setEndpoint('callout:SelfDeploy/services/data/v63.0/tooling/sobjects/ApexClass/describe');
        ping.setMethod('GET');
        new Http().send(ping);
    }

    /** @description True if the SOAP body reports at least one success and no fault. */
    private static Boolean isOk(HttpResponse r) {
        String b = r.getBody();
        return b != null && b.contains('<success>true</success>') && !b.contains('<faultstring>');
    }

    /** @description Pulls a useful error string out of a SOAP fault / result body. */
    private static String extract(String body) {
        if (body == null) return 'empty response';
        Integer a = body.indexOf('<faultstring>');
        if (a >= 0) return body.substring(a + 13, body.indexOf('</faultstring>'));
        a = body.indexOf('<problem>');
        if (a >= 0) return body.substring(a + 9, body.indexOf('</problem>'));
        return body.abbreviate(400);
    }

    /** @description Escapes XML special characters. */
    private static String esc(String s) {
        if (s == null) return '';
        return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
                .replace('"', '&quot;').replace('\'', '&apos;');
    }
}