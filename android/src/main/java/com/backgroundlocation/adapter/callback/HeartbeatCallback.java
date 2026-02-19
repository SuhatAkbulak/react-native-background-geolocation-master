package com.backgroundlocation.adapter.callback;

import com.backgroundlocation.event.HeartbeatEvent;

/**
 * Heartbeat Callback Interface
 * TSHeartbeatCallback
 */
public interface HeartbeatCallback {
    void onHeartbeat(HeartbeatEvent heartbeatEvent);
}

