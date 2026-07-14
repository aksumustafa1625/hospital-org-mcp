/**
 * @description  Coverage for the TriggerHandler base framework (Kevin O'Hara). Uses a private test
 *               handler that records which context method fired, plus a manual test context so the
 *               framework can be exercised without a real DML trigger. Covers dispatch for all
 *               contexts, bypass API, loop-count enforcement, and the outside-trigger guard.
 *
 * @group        DevOps / Framework
 * @author       Mustafa Aksu
 * @since        2026
 */
@isTest
private class TriggerHandlerTest {

    private static final String TRIGGER_CONTEXT_ERROR =
        'Trigger handler called outside of Trigger execution';

    /** Records the last context method that ran, so assertions can verify dispatch. */
    private static String lastMethodCalled;

    /**
     * @description Minimal handler used only for testing. Each override records its name.
     */
    private class TestHandler extends TriggerHandler {
        public override void beforeInsert()   { TriggerHandlerTest.lastMethodCalled = 'beforeInsert'; }
        public override void beforeUpdate()   { TriggerHandlerTest.lastMethodCalled = 'beforeUpdate'; }
        public override void beforeDelete()   { TriggerHandlerTest.lastMethodCalled = 'beforeDelete'; }
        public override void afterInsert()    { TriggerHandlerTest.lastMethodCalled = 'afterInsert'; }
        public override void afterUpdate()    { TriggerHandlerTest.lastMethodCalled = 'afterUpdate'; }
        public override void afterDelete()    { TriggerHandlerTest.lastMethodCalled = 'afterDelete'; }
        public override void afterUndelete()  { TriggerHandlerTest.lastMethodCalled = 'afterUndelete'; }
    }

    /** @description Puts the handler into a chosen context and runs it. */
    private static void runInContext(TestHandler h, String ctx) {
        h.setTriggerContext(ctx, true);
        h.run();
    }

    @isTest
    static void dispatchesEveryContext() {
        TestHandler h = new TestHandler();

        runInContext(h, 'before insert');
        System.assertEquals('beforeInsert', lastMethodCalled, 'before insert should dispatch');

        runInContext(h, 'before update');
        System.assertEquals('beforeUpdate', lastMethodCalled, 'before update should dispatch');

        runInContext(h, 'before delete');
        System.assertEquals('beforeDelete', lastMethodCalled, 'before delete should dispatch');

        runInContext(h, 'after insert');
        System.assertEquals('afterInsert', lastMethodCalled, 'after insert should dispatch');

        runInContext(h, 'after update');
        System.assertEquals('afterUpdate', lastMethodCalled, 'after update should dispatch');

        runInContext(h, 'after delete');
        System.assertEquals('afterDelete', lastMethodCalled, 'after delete should dispatch');

        runInContext(h, 'after undelete');
        System.assertEquals('afterUndelete', lastMethodCalled, 'after undelete should dispatch');
    }

    @isTest
    static void bypassPreventsExecution() {
        TestHandler h = new TestHandler();
        lastMethodCalled = null;

        TriggerHandler.bypass('TestHandler');
        System.assertEquals(true, TriggerHandler.isBypassed('TestHandler'),
            'handler should report bypassed');

        runInContext(h, 'before insert');
        System.assertEquals(null, lastMethodCalled, 'bypassed handler should not run');

        TriggerHandler.clearBypass('TestHandler');
        System.assertEquals(false, TriggerHandler.isBypassed('TestHandler'),
            'handler should no longer be bypassed');

        runInContext(h, 'before insert');
        System.assertEquals('beforeInsert', lastMethodCalled, 'cleared handler should run again');

        // Also exercise the clear-all path.
        TriggerHandler.bypass('TestHandler');
        TriggerHandler.clearAllBypasses();
        System.assertEquals(false, TriggerHandler.isBypassed('TestHandler'),
            'clearAllBypasses should reset everything');
    }

    @isTest
    static void loopCountThrowsWhenExceeded() {
        TestHandler h = new TestHandler();
        h.setMaxLoopCount(1);

        Boolean threw = false;
        try {
            runInContext(h, 'before insert'); // 1st run — allowed
            runInContext(h, 'before insert'); // 2nd run — should throw
        } catch (TriggerHandler.TriggerHandlerException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'exceeding the max loop count should throw');

        // clearMaxLoopCount should remove the restriction.
        h.clearMaxLoopCount();
        runInContext(h, 'before insert'); // should not throw now
    }

    @isTest
    static void outsideTriggerContextThrows() {
        TestHandler h = new TestHandler();
        Boolean threw = false;
        try {
            // No context set and not in a trigger → validateRun should throw.
            h.run();
        } catch (TriggerHandler.TriggerHandlerException e) {
            threw = true;
            System.assertEquals(TRIGGER_CONTEXT_ERROR, e.getMessage(),
                'message should match the outside-trigger guard');
        }
        System.assertEquals(true, threw, 'running outside trigger context should throw');
    }
}