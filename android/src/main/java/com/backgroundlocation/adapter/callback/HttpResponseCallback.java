package com.backgroundlocation.adapter.callback;

import com.backgroundlocation.event.HttpResponseEvent;

/**
 * HTTP Response Callback Interface
 * TSHttpResponseCallback
 */
public interface HttpResponseCallback {
    void onHttpResponse(HttpResponseEvent httpResponseEvent);
}

