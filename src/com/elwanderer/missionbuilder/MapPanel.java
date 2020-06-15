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

    public MapPanel() {
        // TODO Auto-generated constructor stub
    }

    public MapPanel(LayoutManager arg0) {
        super(arg0);
        // TODO Auto-generated constructor stub
    }

    public MapPanel(boolean arg0) {
        super(arg0);
        // TODO Auto-generated constructor stub
    }

    public MapPanel(LayoutManager arg0, boolean arg1) {
        super(arg0, arg1);
        // TODO Auto-generated constructor stub
    }

    public void initialiseMap() {

        // TODO - define size?
        // TODO - define KSP things like timestamp and central body?
        // - or pass in a vector of space objects?

        initialised = true;
    }

    public void paintComponent(Graphics g) {
        super.paintComponent(g);

        Graphics2D g2 = (Graphics2D) g;

        if (initialised) {
            // TODO
        }

        /*
         * EXPERIMENTAL CODE
         */

        double universalTime = Utils.getSecondsInYear() * 2;

        double sunSize = 10;
        double centralPositionX = 250 - (sunSize / 2);
        double centralPositionY = 250 - (sunSize / 2);
        g2.setPaint(Color.YELLOW);
        g2.fill(new Ellipse2D.Double(centralPositionX, centralPositionY, sunSize, sunSize));

        KSPSolarSystem system = new KSPSolarSystem();
        ArrayList<KSPCelestialBody> planets = system.getBodiesOrbiting("SUN");

        double scaleFactor = 5E8;

        for (KSPCelestialBody planet : planets) {

            Orbit o = planet.getOrbit();
            double r_pe = o.getPeriapsis() / scaleFactor;
            double a = o.getSMA() / scaleFactor;
            double b = o.getSemiMinorAxis() / scaleFactor;
            double posX = 250 - r_pe;
            double posY = 250 - b;
            double theta = -Math.toRadians(o.getLAN() + o.getArg() - 90);

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
        }

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
            double theta = -Math.toRadians(o.getLAN() + o.getArg() - 90);

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

    }
}
