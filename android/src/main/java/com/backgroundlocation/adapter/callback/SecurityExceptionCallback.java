package com.backgroundlocation.adapter.callback;

import com.backgroundlocation.event.SecurityExceptionEvent;

/**
 * SecurityExceptionCallback
 * TSSecurityExceptionCallback.java
 * Security exception callback
 */
public interface SecurityExceptionCallback {
    void onSecurityException(SecurityExceptionEvent event);
}

