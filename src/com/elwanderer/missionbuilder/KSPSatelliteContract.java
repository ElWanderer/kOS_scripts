package com.elwanderer.missionbuilder;

public class KSPSatelliteContract extends KSPContract {

	final int bodyID;
	final Orbit orbit;
	
	public KSPSatelliteContract(KSPConfigBlock block) {
		super(block);
		
    	bodyID = block.getIntField("targetBody");
    	
		double i = block.getDoubleField("SpecificOrbitParameter\\inclination");			    			
		double e = block.getDoubleField("SpecificOrbitParameter\\eccentricity");
		double a = block.getDoubleField("SpecificOrbitParameter\\sma");
		double lan = block.getDoubleField("SpecificOrbitParameter\\lan");
		double w = block.getDoubleField("SpecificOrbitParameter\\argumentOfPeriapsis");
		orbit = new Orbit(i, e, a, lan, w);
	}
	
	public int getBodyID() { return bodyID; }
	
	public Orbit getOrbit() { return orbit; }
	
	public String toString() {
		String returnVal = super.toString();
		
		KSPSolarSystem system = new KSPSolarSystem();
		KSPCelestialBody body = system.getBodyByID(bodyID);
		
		returnVal += "Body: " + body.getDescription() + "\n";
		returnVal += OrbitUtils.orbitToStringForBody(orbit, body);
		
		return returnVal;
	}
}
