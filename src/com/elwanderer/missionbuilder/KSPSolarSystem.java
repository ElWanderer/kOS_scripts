package com.elwanderer.missionbuilder;

import java.util.*;

public class KSPSolarSystem {

	final List<KSPCelestialBody> bodies;
	
	private void addStockBodies() {
		// orbit is i, e, a, lan, w
		// body is ID, kOS name, name/description, parent, radius, GM/Mu, sphere of influence radius, orbit, mean anomaly at epoch
		KSPCelestialBody sun = new KSPCelestialBody(0,  "SUN",    "The Sun", null, 261600000,   1.17233279483E18,     -1,      null, 0.0);
		bodies.add(sun);
		
		Orbit mohOrbit = new Orbit( 7.0,   0.2,    5.263138304E9,   70.0,  15.0);
		KSPCelestialBody moh = new KSPCelestialBody(4,  "MOHO",   "Moho",     sun,    250000,   1.68609E11,    9646663.0,  mohOrbit, 3.14);
		bodies.add(moh);
		
		Orbit eveOrbit = new Orbit( 2.1,   0.01,   9.571084544E9,   15.0,   0.0);
		KSPCelestialBody eve = new KSPCelestialBody(5,  "EVE",    "Eve",      sun,    700000, 8.171730229E12, 85109365.0,  eveOrbit, 3.14);
		bodies.add(eve);
		Orbit gilOrbit = new Orbit(12.0,   0.55,          3.15E7,   80.0,  10.0);
		KSPCelestialBody gil = new KSPCelestialBody(13, "GILLY",  "Gilly",    eve,     13000, 8.2894498E6,      126123.27, gilOrbit, 0.9);
		bodies.add(gil);
		
		Orbit kerOrbit = new Orbit( 0.0,   0.0,   1.3599840256E10,   0.0,   0.0);
		KSPCelestialBody ker = new KSPCelestialBody(1,  "KERBIN", "Kerbin",   sun,    600000,    3.5316E12,   84159286.0,  kerOrbit, 3.14);
		bodies.add(ker);
		Orbit munOrbit = new Orbit( 0.0,   0.0,            1.2E7,    0.0,   0.0);
		KSPCelestialBody mun = new KSPCelestialBody(2,  "MUN",    "The Mun",  ker,    200000, 6.5138398E10,    2429559.1,  munOrbit, 1.7);
		bodies.add(mun);
		Orbit minOrbit = new Orbit( 6.0,   0.0,            4.7E7,   78.0,  38.0);
		KSPCelestialBody min = new KSPCelestialBody(3,  "MINMUS", "Minmus",   ker,     60000,    1.7658E9,     2247428.4,  minOrbit, 0.9);
		bodies.add(min);
		
		Orbit dunOrbit = new Orbit( 0.06,  0.051, 2.0726155264E10, 135.5,   0.0);
		KSPCelestialBody dun = new KSPCelestialBody(6,  "DUNA",   "Duna",     sun,    320000, 3.01363212E11,  47921949.0,  dunOrbit, 3.14);
		bodies.add(dun);
		Orbit ikeOrbit = new Orbit( 0.2,   0.03,           3.2E6,    0.0,   0.0);
		KSPCelestialBody ike = new KSPCelestialBody(7,  "IKE",    "Ike",      dun,    130000, 1.8568369E10,    1049598.9,  ikeOrbit, 0.7);
		bodies.add(ike);
		
		Orbit dreOrbit = new Orbit( 5.0,   0.145, 4.0839348203E10, 280.0,  90.0);
		KSPCelestialBody dre = new KSPCelestialBody(15, "DRES",   "Dres",     sun,    138000, 2.1484489E10,   32832840.0,  dreOrbit, 3.14);
		bodies.add(dre);
		
		Orbit jooOrbit = new Orbit( 1.304, 0.05,  6.8773560320E10,  52.0,   0.0);
		KSPCelestialBody joo = new KSPCelestialBody(8,  "JOOL",   "Jool",     sun,   6000000, 2.82528004E14, 2455985200.0, jooOrbit, 0.1);
		bodies.add(joo);
		Orbit layOrbit = new Orbit( 0.0,   0.0,         2.7184E7,    0.0,   0.0);
		KSPCelestialBody lay = new KSPCelestialBody(9,  "LAYTHE", "Laythe",   joo,    500000,     1.962E12,    3723645.8,  layOrbit, 3.14);
		bodies.add(lay);
		Orbit valOrbit = new Orbit( 0.0,   0.0,         4.3152E7,    0.0,   0.0);
		KSPCelestialBody val = new KSPCelestialBody(10, "VALL",   "Vall",     joo,    300000,   2.07482E11,    2406401.4,  valOrbit, 0.9);
		bodies.add(val);
		Orbit tylOrbit = new Orbit( 0.025, 0.0,           6.85E7,    0.0,   0.0);
		KSPCelestialBody tyl = new KSPCelestialBody(12, "TYLO",   "Tylo",     joo,    600000,   2.82528E12,   10856518.0,  tylOrbit, 3.14);
		bodies.add(tyl);
		Orbit bopOrbit = new Orbit(15.0,   0.235,        1.285E8,   10.0,  25.0);
		KSPCelestialBody bop = new KSPCelestialBody(11, "BOP",    "Bop",      joo,     65000,  2.4868349E9,    1221060.9,  bopOrbit, 0.9);
		bodies.add(bop);
		Orbit polOrbit = new Orbit( 4.25,  0.171,       1.7989E8,    2.0,  15.0);
		KSPCelestialBody pol = new KSPCelestialBody(14, "POL",    "Pol",      joo,     44000,  7.2170208E8,    1042138.9,  polOrbit, 0.9);
		bodies.add(pol);
		
		Orbit eelOrbit = new Orbit( 6.15,  0.26,      9.011882E10,  50.0, 260.0);
		KSPCelestialBody eel = new KSPCelestialBody(16, "EELOO",  "Eeloo",    sun,    210000, 7.4410815E10,  119082940.0,  eelOrbit, 3.14);
		bodies.add(eel);
		
		Orbit tesOrbit = new Orbit(15.25,  0.5,       5.011882E10,  50.0, 260.0);
		KSPCelestialBody tes = new KSPCelestialBody(17, "TEST",  "Test",    sun,      210000, 7.4410815E10,  119082940.0,  tesOrbit, 0.0);
		bodies.add(tes);
	}
	
	public KSPSolarSystem() {
		
		bodies = new ArrayList<KSPCelestialBody>();
		
		addStockBodies();
		
	}
	
	public KSPCelestialBody getBodyByID(int bid) {
		KSPCelestialBody returnBody = null;
		boolean found = false;
		Iterator<KSPCelestialBody> it = bodies.iterator();
		while (!found && it.hasNext()) {
			KSPCelestialBody bod = it.next();
    		if (bod.getID() == bid) {
    			found = true;
    			returnBody = bod; 
    		}
		}
		return returnBody;
	}
	
	public KSPCelestialBody getBodyByName(String name) {
		KSPCelestialBody returnBody = null;
		boolean found = false;
		Iterator<KSPCelestialBody> it = bodies.iterator();
		while (!found && it.hasNext()) {
			KSPCelestialBody bod = it.next();
    		if (bod.getName() == name) {
    			found = true;
    			returnBody = bod;
    		}
		}
		return returnBody;
	}
	
	public String toString() {
		String returnVal = "Solar System Details:\n";
		Iterator<KSPCelestialBody> it = bodies.iterator();
		while (it.hasNext()) {
			KSPCelestialBody bod = it.next();
    		returnVal += bod.toString();
		}
		return returnVal;
	}
}
