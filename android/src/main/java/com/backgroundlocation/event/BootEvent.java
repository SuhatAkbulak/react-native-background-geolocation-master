package com.backgroundlocation.event;

import android.content.Context;
import android.content.Intent;

/**
 * BootEvent
 * BootEvent.java
 * Uygulama başlangıcında oluşturulan event
 */
public class BootEvent {
    private final Context context;
    private final Intent intent;
    
    public BootEvent(Context context, Intent intent) {
        this.context = context;
        this.intent = intent;
    }
    
    public Context getContext() {
        return context;
    }
    
    public Intent getIntent() {
        return intent;
    }
    
    public String getEventName() {
        return "boot";
    }
}

