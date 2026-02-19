package com.backgroundlocation.event;

/**
 * StopServiceEvent
 * StopServiceEvent.java
 * Service durdurma event
 */
public class StopServiceEvent {
    private final String serviceName;
    private final String reason;
    
    public StopServiceEvent(String serviceName, String reason) {
        this.serviceName = serviceName;
        this.reason = reason;
    }
    
    public String getServiceName() {
        return serviceName;
    }
    
    public String getReason() {
        return reason;
    }
    
    public String getEventName() {
        return "stopservice";
    }
}

