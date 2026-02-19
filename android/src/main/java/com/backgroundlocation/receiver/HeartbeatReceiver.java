package com.backgroundlocation.receiver;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

import com.backgroundlocation.service.HeartbeatService;

/**
 * Heartbeat Broadcast Receiver
 * AlarmManager'dan gelen heartbeat tetiklemelerini yakalar
 */
public class HeartbeatReceiver extends BroadcastReceiver {
    
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent != null && "HEARTBEAT".equals(intent.getAction())) {
            HeartbeatService.onHeartbeat(context);
        }
    }
}

