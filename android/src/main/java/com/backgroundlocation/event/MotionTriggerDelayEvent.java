package com.backgroundlocation.event;

/**
 * MotionTriggerDelayEvent
 * MotionTriggerDelayEvent
 * Motion trigger gecikme event
 */
public class MotionTriggerDelayEvent {
    public static final String ACTION = "MOTION_TRIGGER_DELAY";
    
    private final long delay;
    private final String reason;
    
    public MotionTriggerDelayEvent(long delay, String reason) {
        this.delay = delay;
        this.reason = reason;
    }
    
    public long getDelay() {
        return delay;
    }
    
    public String getReason() {
        return reason;
    }
    
    public String getEventName() {
        return "motiontriggerdelay";
    }
}

