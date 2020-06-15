package com.elwanderer.missionbuilder;

import java.awt.Color;

public class KSPCelestialBody extends Orbiting {

    static final String BODY_TYPE = "BODY";
    
    final int bodyID;              // integer as appears in the savegame file
    final String bodyDescription;  // prettier name (e.g. "The Sun" instead of "SUN")
    final double radius;           // metres
    final double mu;               // gravitational parameter (equivalent to mass [m] * gravitational constant [G])
                                   // m^3/s^2
    final double soiRadius;        // metres

    // body is ID, kOS name, name/description, parent, radius, GM/Mu, sphere of influence radius, orbit, mean anomaly at epoch, display colour
    public KSPCelestialBody(int bid, String n, String desc, KSPCelestialBody pb,
                            double r, double gm, double sr, Orbit o, double maae_rad, Color c) {

        super(BODY_TYPE, n, pb, o, maae_rad, c);
        
        bodyID = bid;
        bodyDescription = desc;
        radius = r;
        mu = gm;
        soiRadius = sr;
    }

    public int getID() {
        return bodyID;
    }

    public String getDescription() {
        return bodyDescription;
    }

    public double getRadius() {
        return radius;
    }

    public double getMu() {
        return mu;
    }

    public double getSoIRadius() {
        return soiRadius;
    }

    public boolean hasSoIRadius() {
        return soiRadius > 0;
    }

    @Override
    public String toString() {
        String returnVal = "Body details:\n";
        returnVal += "ID: " + bodyID + "\n";
        returnVal += "Name/description: " + name + "/" + bodyDescription + "\n";
        if (hasParent()) {
            returnVal += "Parent Body: " + parent.getName() + "/" + parent.getDescription() + "\n";
        }
        returnVal += "Radius: " + OrbitUtils.distanceToString(radius) + "\n";
        returnVal += "Mu (gravitational parameter): " + mu + "m^3/s^2\n";
        if (hasSoIRadius()) {
            returnVal += "Sphere of influence radius: " + OrbitUtils.distanceToString(soiRadius) + "\n";
        } else {
            returnVal += "Sphere of influence radius: Infinite\n";
        }
        if (hasOrbit()) {
            returnVal += orbit.toString();
            returnVal += "Orbital period: " + getPeriod() + "s\n";
            returnVal += "Mean anomaly at epoch: " + Utils.roundToDP(maae, 3) + " degrees\n";
        }
        return returnVal;
    }
}
