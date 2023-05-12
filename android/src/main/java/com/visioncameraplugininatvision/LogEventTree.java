package com.visioncameraplugininatvision;

import android.content.Context;
import android.util.Log;
import android.view.View;

import com.facebook.react.bridge.*;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import java.text.SimpleDateFormat;
import java.util.Date;

import timber.log.Timber;

public class LogEventTree extends Timber.DebugTree {
    private ReactApplicationContext mContext;
    private String mEventName;

    public LogEventTree(ReactApplicationContext context, String eventName) {
        super();
        mContext = context;
        mEventName = eventName;
    }

    @Override
    protected void log(int priority, String tag, String message, Throwable t) {
        StringBuilder builder = new StringBuilder();

        try {
            Date now = new Date();
            SimpleDateFormat dateString = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");

            String formattedMessage = builder
                    .append(dateString.format(now))
                    .append(": ")
                    .append(tag)
                    .append(": ")
                    .append(message)
                    .toString();

            WritableMap event = Arguments.createMap();
            event.putString("log", formattedMessage);

            mContext
              .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
              .emit(mEventName, event);
        } catch (OutOfMemoryError e) {
            // Can't print to log in this case since the OOM exception is within the log tree itself
            e.printStackTrace();
        }
    }

    @Override
    protected String createStackElementTag(StackTraceElement element) {
        // Add log statements line number to the log
        return super.createStackElementTag(element) + " - #" + element.getLineNumber();
    }
}
