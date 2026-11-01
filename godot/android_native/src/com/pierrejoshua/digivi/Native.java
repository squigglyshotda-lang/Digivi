package com.pierrejoshua.digivi;

import android.app.Activity;
import android.graphics.Bitmap;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.media.FaceDetector;
import android.os.Bundle;
import android.os.Looper;

/** Small helpers the Godot game calls through JavaClassWrapper: location and face detection. */
public class Native {
    private static volatile String lastFix = "";
    private static volatile String status = "idle";
    private static LocationManager manager;
    private static final LocationListener listener = new LocationListener() {
        @Override public void onLocationChanged(Location l) {
            lastFix = l.getLatitude() + "," + l.getLongitude() + "," + (l.hasAccuracy() ? l.getAccuracy() : 9999f);
        }
        @Override public void onStatusChanged(String p, int s, Bundle e) {}
        @Override public void onProviderEnabled(String p) {}
        @Override public void onProviderDisabled(String p) {}
    };

    /** Starts listening for location. Returns "ok", "denied" or "error: ...". */
    public static String startLocation(Activity activity) {
        try {
            manager = (LocationManager) activity.getSystemService("location");
            if (manager == null) return "error: no location service";
            boolean any = false;
            for (String provider : new String[] {"gps", "network", "fused"}) {
                try {
                    if (manager.getAllProviders().contains(provider)) {
                        manager.requestLocationUpdates(provider, 15000L, 0f, listener, Looper.getMainLooper());
                        Location last = manager.getLastKnownLocation(provider);
                        if (last != null && lastFix.isEmpty()) listener.onLocationChanged(last);
                        any = true;
                    }
                } catch (SecurityException se) {
                    return "denied";
                }
            }
            status = any ? "ok" : "error: no providers";
            return status;
        } catch (Throwable t) {
            return "error: " + t;
        }
    }

    /** "lat,lon,accuracy" or "" if there is no fix yet. */
    public static String lastFix() { return lastFix; }

    /** How many faces are in an RGBA image (width must be even). */
    public static int faces(byte[] rgba, int w, int h) {
        try {
            if (w % 2 != 0) w -= 1;
            int[] px = new int[w * h];
            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    int i = (y * w + x) * 4;
                    px[y * w + x] = 0xFF000000 | ((rgba[i] & 0xFF) << 16) | ((rgba[i + 1] & 0xFF) << 8) | (rgba[i + 2] & 0xFF);
                }
            }
            Bitmap bmp = Bitmap.createBitmap(w, h, Bitmap.Config.RGB_565);
            bmp.setPixels(px, 0, w, 0, 0, w, h);
            FaceDetector.Face[] found = new FaceDetector.Face[2];
            int n = new FaceDetector(w, h, 2).findFaces(bmp, found);
            int count = 0;
            for (int i = 0; i < n; i++) if (found[i] != null && found[i].confidence() > 0.4f) count++;
            bmp.recycle();
            return count;
        } catch (Throwable t) {
            return -1;
        }
    }
}
