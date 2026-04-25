package com.nexus.sheildai.sheild_ai.sos

/**
 * SMSTestConfig — Fixed values used by the isolated SMS smoke-test.
 *
 * Change [PHONE_NUMBER] to your test device number before running.
 * This file is the ONLY place that needs to be edited for the test.
 *
 * Used by:
 *  - [MainActivity.registerSmsTestChannel] ("testSMS" method)
 *  - Flutter SmsTestScreen (as default if no arguments are passed)
 *
 * ⚠️  Remove or gate this behind BuildConfig.DEBUG before production release.
 */
object SMSTestConfig {

    /**
     * Destination number for the SMS smoke-test.
     * Use international format (+91XXXXXXXXXX) for best compatibility.
     */
    const val PHONE_NUMBER = "+91XXXXXXXXXX"   // ← replace with your test number

    /**
     * Message body sent during the smoke-test.
     * Kept short (< 160 chars) so it is dispatched as a single SMS part.
     */
    const val MESSAGE = "[SHEild AI] SMS test — if you received this, SmsHelper is working correctly."
}
