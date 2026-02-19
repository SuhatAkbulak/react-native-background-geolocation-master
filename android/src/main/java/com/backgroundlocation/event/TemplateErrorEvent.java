package com.backgroundlocation.event;

/**
 * TemplateErrorEvent
 * TemplateErrorEvent.java
 * Template hata event
 */
public class TemplateErrorEvent {
    private final String template;
    private final String error;
    private final String field;
    
    public TemplateErrorEvent(String template, String error, String field) {
        this.template = template;
        this.error = error;
        this.field = field;
    }
    
    public String getTemplate() {
        return template;
    }
    
    public String getError() {
        return error;
    }
    
    public String getField() {
        return field;
    }
    
    public String getEventName() {
        return "templateerror";
    }
}

