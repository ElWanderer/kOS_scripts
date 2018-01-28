package com.elwanderer.missionbuilder;

public class OrbitUtils {
	public static double roundToDP(double num, int numDP) {
		if (numDP > 0) {
			double exp = Math.pow(10.0, numDP);
			return Math.round(num*exp) / exp;
			
		} else {
			return Math.round(num);
		}
	}
	
	// force an angle to be in the range 0-360 (including 0 but not 360)
	public static double mAngle(double ang) {
		while (ang < 0) { ang += 360; }
		while (ang >= 360) { ang -= 360; }
		return ang;
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
				//double orbits = Math.floor(time / period); // number of orbits in time
				//double rem = time - (orbits * period); // time remaining once whole orbits removed
				//double mae = 360 * rem / period; // mean anomaly elapsed
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
		if (e >= 0.8) { E = Math.PI; }
		double F = eccErr(e, ma, E);
		
		int i=0;
		int maxIt=30;
		while ((Math.abs(F) > delta) && (i < maxIt)) {
			E -= (F/(1-(e*Math.cos(E))));
			F = eccErr(e, ma, E);
			i++;
		}
		//System.out.println("Iterations: " + i);
		return E;
	}
	
	// input mean anomaly and output true anomaly are in degrees
	public static double calculateTrueAnomaly(double e, double ma, int dp) {
		double ea = eccentricAnomaly(e, ma, dp*2);
		double ta = Math.atan2(Math.sqrt(1-Math.pow(e, 2))*Math.sin(ea), Math.cos(ea)-e);
		return roundToDP(mAngle(Math.toDegrees(ta)),dp);
	}
	
	public static double trueAnomalyAtTime(KSPCelestialBody body, double time) {
		return calculateTrueAnomaly(body.getOrbit().getEcc(), meanAnomalyAtTime(body,time), 5);
	}
}
