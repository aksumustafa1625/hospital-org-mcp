/**
 * @description  Thin invocable wrapper that exposes trigger deployment as its own MCP tool /
 *               Flow action ("Deploy Apex Trigger"). Salesforce permits only one
 *               @InvocableMethod per class, so this class carries the trigger action while the
 *               actual Tooling API logic lives in ApexClassDeployer.runTriggerDeploys. Under the
 *               Kevin O'Hara framework the deployed trigger should be a one-liner delegating to
 *               a handler, e.g. 'new InstallationTriggerHandler().run();'.
 *
 * @group        DevOps / Tooling
 * @author       Mustafa Aksu
 * @since        2026
 */
global with sharing class ApexTriggerDeployer {

    /**
     * @description Invocable entry point. Creates or updates each requested Apex trigger via
     *              the Tooling API. Because callouts are involved, this cannot run inside a
     *              trigger context.
     * @param  requests  List of trigger deployment requests (Salesforce passes a bulk list).
     * @return List of results, index-aligned with the input list.
     */
    @InvocableMethod(label='Deploy Apex Trigger'
        description='Creates or updates an Apex trigger in this org via the Tooling API.'
        callout=true)
    global static List<ApexClassDeployer.DeployResult> deploy(List<ApexClassDeployer.DeployTriggerRequest> requests) {
        return ApexClassDeployer.runTriggerDeploys(requests);
    }
}