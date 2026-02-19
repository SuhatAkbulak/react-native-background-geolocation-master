package com.backgroundlocation.event;

/**
 * SettingsFailureEvent
 * SettingsFailureEvent.java
 * Settings başarısızlık event
 */
public class SettingsFailureEvent {
    private final String setting;
    private final String error;
    private final int errorCode;
    
    public SettingsFailureEvent(String setting, String error, int errorCode) {
        this.setting = setting;
        this.error = error;
        this.errorCode = errorCode;
    }
    
    public String getSetting() {
        return setting;
    }
    
    public String getError() {
        return error;
    }
    
    public int getErrorCode() {
        return errorCode;
    }
    
    public String getEventName() {
        return "settingsfailure";
    }
}

