package com.backgroundlocation.adapter.callback;

/**
 * BackgroundTaskCallback
 * TSBackgroundTaskCallback.java
 * Background task callback
 */
public interface BackgroundTaskCallback {
    void onStart(int taskId);
    void onCancel(int taskId);
}

