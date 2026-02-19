package com.backgroundlocation.scheduler;

import android.app.job.JobParameters;
import android.app.job.JobService;
import android.os.PersistableBundle;
import com.backgroundlocation.adapter.BackgroundLocationAdapter;
import com.backgroundlocation.logger.Log;
import com.backgroundlocation.util.LogHelper;

/**
 * ScheduleJobService
 * ScheduleJobService
 * Schedule job service - JobScheduler ile zamanlanmış işler
 */
public class ScheduleJobService extends JobService {
    
    /**
     * Job runner
     */
    private class JobRunner implements Runnable {
        private final JobParameters parameters;
        
        JobRunner(JobParameters parameters) {
            this.parameters = parameters;
        }
        
        @Override
        public void run() {
            PersistableBundle extras = this.parameters.getExtras();
            
            if (extras.containsKey(TSScheduleManager.ACTION_ONESHOT)) {
                // One-shot event
                String action = extras.getString(TSScheduleManager.ACTION_NAME, "");
                ScheduleEvent.onOneShot(
                    ScheduleJobService.this.getApplicationContext(), 
                    action, 
                    new ScheduleEvent.Callback() {
                        @Override
                        public void onFinish() {
                            ScheduleJobService.this.jobFinished(JobRunner.this.parameters, false);
                        }
                    }
                );
            } else if (extras.containsKey("backgroundTask")) {
                // Background task - TODO: Implement BackgroundTaskManager
                LogHelper.w("ScheduleJobService", "BackgroundTaskManager not implemented yet");
                ScheduleJobService.this.jobFinished(this.parameters, false);
            } else {
                // Regular schedule event
                boolean enabled = extras.getBoolean("enabled", false);
                int trackingMode = extras.getInt("trackingMode", 1);
                ScheduleEvent.onScheduleAlarm(
                    ScheduleJobService.this.getApplicationContext(), 
                    enabled, 
                    trackingMode
                );
                ScheduleJobService.this.jobFinished(this.parameters, false);
            }
        }
    }
    
    @Override
    public boolean onStartJob(JobParameters params) {
        BackgroundLocationAdapter.getThreadPool().execute(new JobRunner(params));
        return true;
    }
    
    @Override
    public boolean onStopJob(JobParameters params) {
        Log.logger.debug("");
        return true;
    }
}

