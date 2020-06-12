package com.elwanderer.missionbuilder;

import java.util.Vector;

public class KSPGameState {

	private String saveFileNameWithPath;
	private KSPSolarSystem solarSystem;
	private double universalTime;
	private Vector<KSPSatelliteContract> satelliteContracts;
	
	public KSPGameState(String fn, double ut, Vector<KSPSatelliteContract> satCons) {
		
		saveFileNameWithPath = fn;
		universalTime = ut;
		solarSystem = new KSPSolarSystem(); // default solar system
		satelliteContracts = satCons;
	}
	
	public KSPGameState(String fn, KSPSolarSystem newSystem, double ut, Vector<KSPSatelliteContract> satCons) {
		
		saveFileNameWithPath = fn;
		universalTime = ut;
		solarSystem = newSystem;
		satelliteContracts = satCons;
	}
	
	public String getSaveFileNameWithPath() {
		return saveFileNameWithPath;
	}
	
	public KSPSolarSystem getSolarSystem() {
		return solarSystem;
	}
	
	public double getUT() {
		return universalTime;
	}
	
	public String getTimeString() {		
		return Utils.getTimeString(universalTime);
	}
	
	public Vector<KSPSatelliteContract> getSatelliteContracts() {
		return satelliteContracts;
	}
}
