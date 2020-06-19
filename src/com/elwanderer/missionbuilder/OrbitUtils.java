package com.elwanderer.missionbuilder;

public class OrbitUtils {

    static String[] DISTANCE_SUFFIXES = { "m", "km", "Mm", "Gm", "Tm", "Pm" };
    static int[] NUM_DP_TO_DISPLAY = { 1, 1, 3, 3, 3, 3 };

    /*
     * Display a distance as a string, using m, km, Mm, Gm as necessary
     */
    public static String distanceToString(double distanceInMetres) {

        int maxSuffixIndex = DISTANCE_SUFFIXES.length - 1;

        int suffixIndex = 0;
        double distance = distanceInMetres;

        while (distance > 1000.0 && suffixIndex < maxSuffixIndex) {
            suffixIndex++;
            distance = distance / 1000.0;
        }

        String returnVal = Utils.roundToDP(distance, NUM_DP_TO_DISPLAY[suffixIndex]) + DISTANCE_SUFFIXES[suffixIndex];
        return returnVal;
    }

    public static String orbitToStringForBody(Orbit o, KSPCelestialBody b) {

        String returnVal = o.toString();

        returnVal += "Apoapsis: " + OrbitUtils.distanceToString(o.getApoapsis(b.getRadius())) + "\n";
        returnVal += "Periapsis: " + OrbitUtils.distanceToString(o.getPeriapsis(b.getRadius())) + "\n";

        return returnVal;
    }

    // force an angle to be in the range 0-360 (including 0 but not 360)
    public static double mAngle(double ang) {
        while (ang < 0) {
            ang += 360;
        }
        while (ang >= 360) {
            ang -= 360;
        }
        return ang;
    }
    
    // force an angle to be in the range 0-360 (including 0 but not 360), then return as radians
    public static double mAngleConvertToRadians(double ang) {
        return Math.toRadians(mAngle(ang));
    }

    // radians per second
    public static double meanMotion(double a, double pmu) {
        return Math.sqrt(pmu / Math.pow(a, 3));
    }

    // seconds
    public static double orbitalPeriod(double a, double pmu) {
        return 2 * Math.PI / meanMotion(a, pmu);
    }

    // degrees
    public static double meanAnomalyAtTime(KSPCelestialBody body, double time) {
        double maat = 0.0;

        if (body.hasParent() && body.hasOrbit()) {
            double period = body.getPeriod();
            if (period > 0) {
                double mae = 360 * time / period; // mean anomaly elapsed
                maat = mAngle(body.getMeanAnomalyAtEpoch() + mae);
            }
        }

        return maat;
    }

    // e is eccentricity
    // ma is mean anomaly in radians
    // E is the calculated (but not necessarily accurate) eccentric anomaly in radians
    // returns the error from the value of mean anomaly that this value of E produces
    public static double eccErr(double e, double ma, double E) {
        return E - (e * Math.sin(E)) - ma;
    }

    // input mean anomaly is assumed to be in degrees
    // output is in radians
    public static double eccentricAnomaly(double e, double ma, int dp) {

        ma = Math.toRadians(ma);

        double delta = Math.pow(10, -dp);
        double E = ma;
        if (e >= 0.8) {
            E = Math.PI;
        }
        double F = eccErr(e, ma, E);

        int i = 0;
        int maxIt = 30;
        while ((Math.abs(F) > delta) && (i < maxIt)) {
            E -= (F / (1 - (e * Math.cos(E))));
            F = eccErr(e, ma, E);
            i++;
        }
        // System.out.println("Iterations: " + i);
        return E;
    }

    // input mean anomaly and output true anomaly are in degrees
    public static double calculateTrueAnomaly(double e, double ma, int dp) {
        double ea = eccentricAnomaly(e, ma, dp * 2);
        double ta = Math.atan2(Math.sqrt(1 - Math.pow(e, 2)) * Math.sin(ea), Math.cos(ea) - e);
        return Utils.roundToDP(mAngle(Math.toDegrees(ta)), dp);
    }

    public static double trueAnomalyAtTime(KSPCelestialBody body, double time) {
        return calculateTrueAnomaly(body.getOrbit().getEcc(), meanAnomalyAtTime(body, time), 5);
    }
    
    // input true anomaly in radians
    public static double radiusAtTrueAnomaly(double a, double e, double ta_rads) {
        return (a * (1 - Math.pow(e, 2))) / (1 + (e * Math.cos(ta_rads)));
    }

    // input true anomaly in degrees
    public static double radiusAtTrueAnomaly(Orbit o, double ta_degrees) {

        double a = o.getSMA();
        double e = o.getEcc();
        double ta_rads = Math.toRadians(ta_degrees);

        return radiusAtTrueAnomaly(a, e, ta_rads);
    }
    
    public static double meanAnomalyFromTA(double ta_rads, double e) {
        
        double ma = 0.0;
        
        if (ta_rads < 0 ) { ta_rads = (2* Math.PI) - ta_rads; }
        if (e < 1) {
            double ea = Math.acos( (e + Math.cos(ta_rads)) / (1 + (e * Math.cos(ta_rads))) );
            if (ta_rads > Math.PI) {
                ea = (2 * Math.PI) - ea;
            }
            ma = ea - (e * Math.sin(ea));
            
        } else if (e > 1) {
            double x = (e + Math.cos(ta_rads)) / (1 + (e * Math.cos(ta_rads)));
            double F = Math.log(x + Math.sqrt(Math.pow(x, 2) - 1));
            ma = (e * Math.sinh(F)) - F;
            if (ta_rads > Math.PI) {
                ma = -ma;
            }
        }
        
        return ma;
    }

    // time taken to go from ta1 to ta2 (input in rads)
    // pmu is the value of mu for the parent body
    public static double secondsToTA(double a, double e, double pmu, double ta1_rads, double ta2_rads) {

        double ma1 = meanAnomalyFromTA(ta1_rads, e);
        double ma2 = meanAnomalyFromTA(ta2_rads, e);
        
        double seconds = (ma2 - ma1) / meanMotion(a, pmu);
        while (seconds < 0) {
            seconds += orbitalPeriod(a, pmu);
        }
        
        return seconds;
    }
}
