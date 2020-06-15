package com.elwanderer.missionbuilder;

import java.awt.Color;

public class Orbiting {

    final String type;             // is this a planet, a craft..?
    final String name;
    final KSPCelestialBody parent; // the body this orbits, null for bodies with no parent
    final Orbit orbit;             // Keplerian orbit plane defined by five parameters
    final double maae;             // mean anomaly (degrees) at epoch (time 0 in game universe)
                                   // - defines where in orbit body is
                                   // - passed in using radians, so needs converting
    final Color displayColour;     // what colour to display on the map
    
    public Orbiting(String t, String n, KSPCelestialBody pb, Orbit o, double maae_rad, Color c) {
        type = t;
        name = n;
        parent = pb;
        orbit = o;
        maae = Math.toDegrees(maae_rad);
        displayColour = c;
    }

    public String getType() {
        return type;
    }

    public String getName() {
        return name;
    }

    public KSPCelestialBody getParent() {
        return parent;
    }

    public boolean hasParent() {
        return parent != null;
    }

    public boolean hasOrbit() {
        return orbit != null;
    }

    public Orbit getOrbit() {
        return orbit;
    }

    public double getMeanAnomalyAtEpoch() {
        return maae;
    }

    public Color getDisplayColour() {
        return displayColour;
    }

    public double getPeriod() {
        double p = 0.0;
        if (hasParent() && hasOrbit()) {
            p = OrbitUtils.orbitalPeriod(orbit.getSMA(), parent.getMu());
        }
        return p;
    }

    @Override
    public String toString() {
        String returnVal = "Orbiting object details:\n";
        returnVal += "Name: " + name + "\n";
        returnVal += "Type: " + type + "\n";
        if (hasParent()) {
            returnVal += "Parent Body: " + parent.getName() + "/" + parent.getDescription() + "\n";
        }
        if (hasOrbit()) {
            returnVal += orbit.toString();
            returnVal += "Orbital period: " + getPeriod() + "s\n";
            returnVal += "Mean anomaly at epoch: " + Utils.roundToDP(maae, 3) + " degrees\n";
        }
        return returnVal;
    }
}
