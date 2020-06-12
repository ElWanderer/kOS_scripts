package com.elwanderer.missionbuilder;

public class KSPCelestialBody {
	
	final int bodyID; 				// integer as appears in the savegame file
	final String bodyName; 			// as used by kOS
	final String bodyDescription; 	// prettier name (e.g. "The Sun" instead of "SUN")
	final KSPCelestialBody parent;	// the body this orbits, null for bodies with no parent
	final double radius;			// metres
	final double mu;				// gravitational parameter (equivalent to mass [m] * gravitational constant [G]) m^3/s^2
	final double soiRadius;			// metres
	final Orbit orbit;				// Keplerian orbit plane defined by five parameters
	final double maae;				// mean anomaly (degrees) at epoch (time 0 in game universe)
									//  - defines where in orbit body is
									//  - passed in using radians, so needs converting
	
	public KSPCelestialBody(int bid, String name, String desc, KSPCelestialBody pb, double r, double gm, double sr, Orbit o, double maae_rad) {
		bodyID = bid;
		bodyName = name;
		bodyDescription = desc;
		parent = pb;
		radius = r;
		mu = gm;
		soiRadius = sr;
		orbit = o;
		maae = Math.toDegrees(maae_rad);
	}

	public int getID() { return bodyID; }
	public String getName() { return bodyName; }
	public String getDescription() { return bodyDescription; }
	
	public KSPCelestialBody getParent() { return parent; }
	public boolean hasParent() { return parent != null; }
	
	public double getRadius() { return radius; }
	public double getMu() { return mu; }
	
	public double getSoIRadius() { return soiRadius; }
	public boolean hasSoIRadius() { return soiRadius > 0; }
	
	public boolean hasOrbit() { return orbit != null; }
	public Orbit getOrbit() { return orbit; }

	public double getMeanAnomalyAtEpoch() { return maae; }
	
	public double getPeriod() {
		double p = 0.0;
		if (hasParent() && hasOrbit()) {
			p = OrbitUtils.orbitalPeriod(orbit.getSMA(), parent.getMu());
		}
		return p;
	}
	
	public String toString() {
		String returnVal = "Body details:\n";
		returnVal += "ID: " + bodyID + "\n";
		returnVal += "Name/description: " + bodyName + "/" + bodyDescription + "\n";
		if (hasParent()) {
			returnVal += "Parent Body: " + parent.getName() + "/" + parent.getDescription() + "\n";
		}
		returnVal += "Radius: " + radius + "m\n";
		returnVal += "Mu (gravitational parameter): " + mu + "m^3/s^2\n";
		if (hasSoIRadius()) {
			returnVal += "Sphere of influence radius: " + soiRadius + "m\n";
		} else {
			returnVal += "Sphere of influence radius: Infinite\n";
		}
		if (hasOrbit()) {
			returnVal += orbit.toString();
			returnVal += "Orbital period: " + getPeriod() + "s\n";
			returnVal += "Mean anomaly at epoch: " + Utils.roundToDP(maae,3) + " degrees\n";
		}
		return returnVal;
	}
}
