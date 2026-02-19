package com.backgroundlocation.adapter.callback;

import com.backgroundlocation.event.AuthorizationEvent;

/**
 * AuthorizationCallback
 * TSAuthorizationCallback.java
 * Authorization event callback
 */
public interface AuthorizationCallback {
    void onResponse(AuthorizationEvent event);
}

