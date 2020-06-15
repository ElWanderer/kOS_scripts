package com.elwanderer.missionbuilder;

import java.awt.Color;
import java.awt.Graphics;
import java.awt.Graphics2D;
import java.awt.LayoutManager;
import java.awt.geom.AffineTransform;
import java.awt.geom.Ellipse2D;
import java.util.ArrayList;

import javax.swing.JPanel;

public class MapPanel extends JPanel {

    private boolean initialised = false;
    
    private double universalTime = 0.0;
    private double scaleFactor = 5E8;
    
    private double centralBodySize = 12;
    private double bodySize = 10;
    private double nonBodySize = 6;
    
    private KSPCelestialBody centralBody;
    private ArrayList<KSPCelestialBody> bodies;
    private ArrayList<Orbiting> nonBodies;

    public MapPanel() {
        super();
        initialised = false;
        centralBody = null;
    }

    public MapPanel(LayoutManager arg0) {
        super(arg0);
        initialised = false;
        centralBody = null;
    }

    public MapPanel(boolean arg0) {
        super(arg0);
        initialised = false;
        centralBody = null;
    }

    public MapPanel(LayoutManager arg0, boolean arg1) {
        super(arg0, arg1);
        initialised = false;
        centralBody = null;
    }

    public void initialiseMap(KSPGameState gameState, String centralBodyName) {

        KSPSolarSystem system = gameState.getSolarSystem();
        // read bodies from system into bodies
        centralBody = system.getBodyByName(centralBodyName); // TODO - check this exists first?
        bodies = system.getBodiesOrbiting(centralBody);
        nonBodies = new ArrayList<Orbiting>();
        universalTime = gameState.getUT();
        
        System.out.println("Timestamp: " + universalTime);
        System.out.println("Central body: " + centralBody.getName());
        for (KSPCelestialBody body : bodies) {
            System.out.println(body.getName());
        }
        for (Orbiting nonBody : nonBodies) {
            System.out.println(nonBody.getName());
        }

        initialised = true;
        setVisible(true);
    }

    public void paintComponent(Graphics g) {
        super.paintComponent(g);

        Graphics2D g2 = (Graphics2D) g;

        if (initialised && centralBody != null) {
            
            double halfWidth  = getWidth()  / 2;
            double halfHeight = getHeight() / 2;
            
            double centralPositionX = halfWidth  - (centralBodySize / 2);
            double centralPositionY = halfHeight - (centralBodySize / 2);
            
            // draw central body
            g2.setPaint(centralBody.getDisplayColour());
            g2.fill(new Ellipse2D.Double(centralPositionX, centralPositionY, centralBodySize, centralBodySize));                
            
            // draw planets
            if (bodies != null && bodies.size() > 0) {
                for (KSPCelestialBody planet : bodies) {
                    Orbit o = planet.getOrbit();
                    double r_pe = o.getPeriapsis() / scaleFactor;
                    double a = o.getSMA() / scaleFactor;
                    double b = o.getSemiMinorAxis() / scaleFactor;
                    double posX = halfWidth - r_pe;
                    double posY = halfHeight - b;
                    double theta = -Math.toRadians(o.getLAN() + o.getArg() - 90); // -90 because we calculate ellipses initially with periapsis on the left

                    g2.setPaint(planet.getDisplayColour());
                    g2.draw(AffineTransform.getRotateInstance(theta, halfWidth, halfHeight)
                            .createTransformedShape(new Ellipse2D.Double(posX, posY, 2 * a, 2 * b)));

                    double ta_degrees = OrbitUtils.trueAnomalyAtTime(planet, universalTime);
                    double orbitRadius = OrbitUtils.radiusAtTrueAnomaly(planet.getOrbit(), ta_degrees) / scaleFactor;
                    double bodyPosX = halfWidth - (bodySize / 2);
                    double bodyPosY = halfHeight - (orbitRadius + (bodySize / 2));
                    g2.fill(AffineTransform.getRotateInstance(-Math.toRadians(ta_degrees + o.getLAN() + o.getArg()), halfWidth, halfHeight)
                            .createTransformedShape(new Ellipse2D.Double(bodyPosX, bodyPosY, bodySize, bodySize)));
                }
            }
            
            // draw non-planets
            if (nonBodies != null && nonBodies.size() > 0) {
                for (Orbiting orbiting : nonBodies) {
                    // TODO - similar code to that for bodies, but with smaller display size?
                }                
            }
        }

        /*
         * EXPERIMENTAL CODE
         *

        double universalTime = Utils.getSecondsInYear() * 0;

        double sunSize = 10;
        double centralPositionX = 250 - (sunSize / 2);
        double centralPositionY = 250 - (sunSize / 2);
        g2.setPaint(Color.YELLOW);
        g2.fill(new Ellipse2D.Double(centralPositionX, centralPositionY, sunSize, sunSize));

        KSPSolarSystem system = new KSPSolarSystem();
        ArrayList<KSPCelestialBody> planets = system.getBodiesOrbiting("SUN");

        for (KSPCelestialBody planet : planets) {

            Orbit o = planet.getOrbit();
            double r_pe = o.getPeriapsis() / scaleFactor;
            double a = o.getSMA() / scaleFactor;
            double b = o.getSemiMinorAxis() / scaleFactor;
            double posX = 250 - r_pe;
            double posY = 250 - b;
            double theta = -Math.toRadians(o.getLAN() + o.getArg() - 90); // -90 because we calculate ellipses initially with periapsis on the left

            g2.setPaint(planet.getDisplayColour());
            g2.draw(AffineTransform.getRotateInstance(theta, 250, 250)
                    .createTransformedShape(new Ellipse2D.Double(posX, posY, 2 * a, 2 * b)));

            double ta_degrees = OrbitUtils.trueAnomalyAtTime(planet, universalTime);
            double orbitRadius = OrbitUtils.radiusAtTrueAnomaly(planet.getOrbit(), ta_degrees) / scaleFactor;
            double bodySize = 6;
            double bodyPosX = 250 - (bodySize / 2);
            double bodyPosY = 250 - (orbitRadius + (bodySize / 2));
            g2.fill(AffineTransform.getRotateInstance(-Math.toRadians(ta_degrees + o.getLAN() + o.getArg()), 250, 250)
                    .createTransformedShape(new Ellipse2D.Double(bodyPosX, bodyPosY, bodySize, bodySize)));
        }*/

        /*
        double joolSize = 8;
        double joolPositionX = 750 - (joolSize / 2);
        double joolPositionY = 250 - (joolSize / 2);
        g2.setPaint(Color.GREEN);
        g2.fill(new Ellipse2D.Double(joolPositionX, joolPositionY, joolSize, joolSize));

        ArrayList<KSPCelestialBody> moons = system.getBodiesOrbiting("JOOL");

        double joolScaleFactor = 1E6;

        for (KSPCelestialBody moon : moons) {

            Orbit o = moon.getOrbit();
            double r_pe = o.getPeriapsis() / joolScaleFactor;
            double a = o.getSMA() / joolScaleFactor;
            double b = o.getSemiMinorAxis() / joolScaleFactor;
            double posX = 750 - r_pe;
            double posY = 250 - b;
            double theta = -Math.toRadians(o.getLAN() + o.getArg() - 90); // -90 because we calculate ellipses initially with periapsis on the left

            g2.setPaint(moon.getDisplayColour());
            g2.draw(AffineTransform.getRotateInstance(theta, 750, 250)
                    .createTransformedShape(new Ellipse2D.Double(posX, posY, 2 * a, 2 * b)));

            double ta_degrees = OrbitUtils.trueAnomalyAtTime(moon, universalTime);
            double orbitRadius = OrbitUtils.radiusAtTrueAnomaly(moon.getOrbit(), ta_degrees) / joolScaleFactor;
            double bodySize = 5;
            double bodyPosX = 750 - (bodySize / 2);
            double bodyPosY = 250 - (orbitRadius + (bodySize / 2));
            g2.fill(AffineTransform.getRotateInstance(-Math.toRadians(ta_degrees + o.getLAN() + o.getArg()), 750, 250)
                    .createTransformedShape(new Ellipse2D.Double(bodyPosX, bodyPosY, bodySize, bodySize)));
        }
        */
    }
}
