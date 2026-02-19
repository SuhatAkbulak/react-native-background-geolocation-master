package com.backgroundlocation.adapter.callback;

/**
 * EmailLogCallback
 * TSEmailLogCallback.java
 * Email log callback
 */
public interface EmailLogCallback {
    void onSuccess();
    void onFailure(String error);
}

