package com.elwanderer.missionbuilder;

public class Orbit {

	final double inclination; 			// degrees
	final double eccentricity;
	final double sma; 					// metres
	final double lan; 					// degrees
	final double argumentOfPeriapsis; 	// degrees
	
	// the following specify a position on the orbit
	//final double meanAnomalyAtEpoch;
	//final double epoch;
	//final String epochType;
	
	// the following require knowing the body's radius
	//final double apoapsis; 			// metres
	//final double periapsis;			// metres

	public Orbit(double i, double e, double a, double l, double w) {
		inclination = i;
		eccentricity = e;
		sma = a;
		lan = l;
		argumentOfPeriapsis = w;
	}
	
	public double getInc() { return inclination; }
	public double getEcc() { return eccentricity; }
	public double getSMA() { return sma; }
	public double getLAN() { return lan; }
	public double getArg() { return argumentOfPeriapsis; }
	
	// periapsis radius calculated from centre of body
	// must subtract the body radius to get values as seen in the game
	public double getPeriapsis() {
		return sma * (1-eccentricity);
	}
	public double getPeriapsis(double radius) {
		return getPeriapsis() - radius;
	}
	
	// apoapsis radius calculated from centre of body
	// must subtract the body radius to get values as seen in the game
	public double getApoapsis() {
		return sma * (1+eccentricity);
	}
	public double getApoapsis(double radius) {
		return getApoapsis() - radius;
	}

	public String toString() {
		String returnVal = "Orbit details:\n";
		
		returnVal += "Inclination: " + Utils.roundToDP(inclination,3) + " degrees\n";
		returnVal += "Eccentricity: " + Utils.roundToDP(eccentricity,5) + "\n";
		returnVal += "Semi-major axis: " + OrbitUtils.distanceToString(sma) + "\n";
		returnVal += "Longitude of the ascending node: " + Utils.roundToDP(lan,3) + " degrees\n";
		returnVal += "Argument of periapsis: " + Utils.roundToDP(argumentOfPeriapsis,3) + " degrees\n";
		
		return returnVal;
	}
}
