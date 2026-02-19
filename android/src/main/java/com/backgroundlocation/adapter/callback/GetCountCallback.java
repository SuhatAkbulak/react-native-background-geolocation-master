package com.backgroundlocation.adapter.callback;

/**
 * GetCountCallback
 * TSGetCountCallback.java
 * Count get callback
 */
public interface GetCountCallback {
    void onSuccess(Integer count);
    void onFailure(String error);
}

