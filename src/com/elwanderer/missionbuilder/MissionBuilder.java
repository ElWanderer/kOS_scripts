package com.elwanderer.missionbuilder;

import java.io.*;
import java.awt.*;
import java.awt.event.*;
import javax.swing.*;
import javax.swing.SwingUtilities;
import javax.swing.filechooser.FileNameExtensionFilter;

public class MissionBuilder extends JPanel implements ActionListener {

    static private final String newline = "\n";
    JButton openButton;
    JButton viewContractsButton;
    JLabel saveFileLabel;
    JLabel calendarLabel;
    JTextArea log;
    JFileChooser fc;
    JPanel mainPanel;
    MapPanel mapPanel;
    SatelliteContractPanel satConPanel;
    JPanel secondaryPanel;
    JButton mapZoomInButton;
    JButton mapZoomResetButton;
    JButton mapZoomOutButton;

    KSPGameState gameState;
    boolean saveLoaded = false;

    public MissionBuilder() {
        super(new BorderLayout());

        // Create the log first, because the action listeners
        // need to refer to it.
        log = new JTextArea(3, 20);
        log.setMargin(new Insets(5, 5, 5, 5));
        log.setEditable(false);
        log.setBackground(Color.LIGHT_GRAY);
        JScrollPane logScrollPane = new JScrollPane(log);

        saveFileLabel = new JLabel("");
        saveFileLabel.setPreferredSize(new Dimension(850, 25));
        saveFileLabel.setHorizontalAlignment(SwingConstants.LEFT);

        calendarLabel = new JLabel("");
        calendarLabel.setPreferredSize(new Dimension(150, 25));
        calendarLabel.setHorizontalAlignment(SwingConstants.RIGHT);

        // Create a file chooser
        fc = new JFileChooser();
        fc.setFileSelectionMode(JFileChooser.FILES_AND_DIRECTORIES);
        // create filters
        FileNameExtensionFilter sfsFilter = new FileNameExtensionFilter("sfs files (*.sfs)", "sfs");
        // add filters
        fc.addChoosableFileFilter(sfsFilter);

        // set selected filter
        fc.setFileFilter(sfsFilter);

        // set starting directory
        String[] paths = { "Steam", "steamapps", "common" };
        String defaultFilePath = Utils.getDirectoryUnderProgramFilesX86(paths);
        File path = new File(defaultFilePath);
        if (path.exists()) {
            fc.setCurrentDirectory(path);
        }

        // Create the main buttons
        openButton = new JButton("Open a File...");
        openButton.addActionListener(this);

        viewContractsButton = new JButton("View Contracts");
        viewContractsButton.addActionListener(this);

        refreshButtonStates();

        // For layout purposes, put the buttons in a separate panel
        JPanel buttonPanel = new JPanel(); // use FlowLayout
        buttonPanel.add(openButton);
        buttonPanel.add(viewContractsButton);

        JPanel summaryPanel = new JPanel(); // use FlowLayout
        summaryPanel.add(saveFileLabel);
        summaryPanel.add(calendarLabel);
        
        secondaryPanel = new JPanel();
        secondaryPanel.setVisible(true);
        secondaryPanel.setBackground(Color.WHITE);
        secondaryPanel.setPreferredSize(new Dimension(500, 500));
        
        mapPanel = new MapPanel();
        mapPanel.setVisible(false);
        mapPanel.setBackground(Color.BLACK);
        mapPanel.setPreferredSize(new Dimension(500, 500));
        
        JPanel mainPanel = new JPanel();
        mainPanel.setPreferredSize(new Dimension(1000, 500));
        mainPanel.setBackground(Color.WHITE);
        mainPanel.add(mapPanel);
        mainPanel.add(secondaryPanel);
        
        // Create the map zoom buttons.
        mapZoomOutButton = new JButton("-");
        mapZoomOutButton.addActionListener(this);
        mapZoomOutButton.setBounds(5, 5, 20, 20);
        mapZoomResetButton = new JButton("100%");
        mapZoomResetButton.addActionListener(this);
        mapZoomResetButton.setBounds(30, 5, 30, 20);
        mapZoomInButton = new JButton("+");
        mapZoomInButton.addActionListener(this);
        mapZoomInButton.setBounds(65, 5, 20, 20);
        mapPanel.add(mapZoomOutButton);
        mapPanel.add(mapZoomResetButton);
        mapPanel.add(mapZoomInButton);
        
        JPanel mainWindow = new JPanel(new BorderLayout());
        mainWindow.add(summaryPanel, BorderLayout.PAGE_START);
        mainWindow.add(mainPanel, BorderLayout.CENTER);

        // Add the buttons and the log to this panel.
        add(buttonPanel, BorderLayout.PAGE_START);
        add(mainWindow, BorderLayout.CENTER);
        add(logScrollPane, BorderLayout.PAGE_END);
    }

    private void refreshButtonStates() {
        viewContractsButton.setEnabled(saveLoaded);
    }

    private void refreshSummaryPanel() {

        String saveFileLabelText = "";
        String calendarLabelText = "";

        if (saveLoaded) {
            saveFileLabelText = gameState.getSaveFileNameWithPath();
            calendarLabelText = gameState.getTimeString();
        }

        saveFileLabel.setText(saveFileLabelText);
        calendarLabel.setText(calendarLabelText);
    }

    public void actionPerformed(ActionEvent e) {

        // Handle open button action.
        if (e.getSource() == openButton) {
            int fileChooserOption = fc.showOpenDialog(MissionBuilder.this);

            if (fileChooserOption == JFileChooser.APPROVE_OPTION) {
                File file = fc.getSelectedFile();

                log.append("Opening: " + file.getName() + "..." + newline);
                KSPSaveFileReader sfr = new KSPSaveFileReader();

                try {
                    gameState = sfr.LoadKSPSave(file.getPath());
                    mapPanel.initialiseMap(gameState, "SUN"); // TODO - do we want this as the default?
                    log.append("Done" + newline);
                } catch (IOException ex) {
                    log.append("Error opening: " + file.getName() + "." + newline);
                }
            }
            log.setCaretPosition(log.getDocument().getLength());

            saveLoaded = (gameState != null);
            refreshButtonStates();
            refreshSummaryPanel();
            
        } else if (e.getSource() == viewContractsButton) {

            satConPanel = new SatelliteContractPanel();
            satConPanel.initialiseContracts(gameState);
            secondaryPanel.removeAll();
            secondaryPanel.add(satConPanel);
            
        } else if (e.getSource() == mapZoomOutButton) {
            mapPanel.zoomOut();
        } else if (e.getSource() == mapZoomResetButton) {
            mapPanel.resetZoom();
        } else if (e.getSource() == mapZoomInButton) {
            mapPanel.zoomIn();
        }
    }

    private static void createAndShowGUI() {
        // Create and set up the window.
        JFrame frame = new JFrame("Mission Builder");
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);

        // Add content to the window.
        frame.add(new MissionBuilder());

        // Display the window.
        frame.pack();
        frame.setVisible(true);
    }

    public static void main(String[] args) throws IOException {

        SwingUtilities.invokeLater(new Runnable() {
            public void run() {
                // Turn off metal's use of bold fonts
                UIManager.put("swing.boldMetal", Boolean.FALSE);
                createAndShowGUI();
            }
        });

        /*
         * KSPSaveFileReader sfr = new KSPSaveFileReader(); String path =
         * "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Kerbal Space Program v1.3.1\\saves\\Geoff_1_3_1-Career\\persistent_copy.sfs"
         * ; sfr.LoadKSPContracts(path);
         */

        /*
         * double time = 103208329.879951; // time 103208329.879951 // should produce:
         * // Kerbin 256.940169 // Moho 42.281699 // Gilly 214.474665 // Bop 225.709018
         * // Pol 200.154879 // Jool 0.809396 KSPSolarSystem system = new
         * KSPSolarSystem(); //System.out.println(system.toString()); KSPCelestialBody
         * kerbin = system.getBodyByName("KERBIN"); KSPCelestialBody moho =
         * system.getBodyByName("MOHO"); KSPCelestialBody gilly =
         * system.getBodyByName("GILLY"); KSPCelestialBody bop =
         * system.getBodyByName("BOP"); KSPCelestialBody pol =
         * system.getBodyByName("POL"); KSPCelestialBody jool =
         * system.getBodyByName("JOOL"); //KSPCelestialBody testBody =
         * system.getBodyByName("TEST"); double tak =
         * OrbitUtils.trueAnomalyAtTime(kerbin, time);
         * System.out.println("Kerbin's true anomaly = " + tak); double tam =
         * OrbitUtils.trueAnomalyAtTime(moho, 1283646);
         * System.out.println("Moho's true anomaly = " + tam);
         * //System.out.println("Moho's period = " + moho.getPeriod()); double tag =
         * OrbitUtils.trueAnomalyAtTime(gilly, time);
         * System.out.println("Gilly's true anomaly = " + tag);
         * //System.out.println("Gilly's period = " + gilly.getPeriod()); double tab =
         * OrbitUtils.trueAnomalyAtTime(bop, time);
         * System.out.println("Bop's true anomaly = " + tab); double tap =
         * OrbitUtils.trueAnomalyAtTime(pol, time);
         * System.out.println("Pol's true anomaly = " + tap); double taj =
         * OrbitUtils.trueAnomalyAtTime(jool, time);
         * System.out.println("Jool's true anomaly = " + taj);
         */
        
        /*
         * Testing the calculations needed to work out transfers
         */
        
        // inputs
        double pmu = 3.986E5; // Mu of parent body
        double r1 = 10000; // m - distance to central body from current body (P1)
        double r2 = 16000; // m - distance to central body from target body (p2) at arrival time
        double alpha = 100; // degrees, angle between r1 vector and r2 vector
        double transfer_time = 6000;
        
        // TODO - loop until transfer time matches arrival time - current time
        // variable input
        double y = 30000;

        // temporary variables - independent of y
        double rm = 0.5 * (r1 + r2); // mean of r1 and r2
        double d = 0.5 * Math.sqrt(Math.pow(r1, 2) + Math.pow(r2, 2) - (2 * r1 * r2 * Utils.cos(alpha))); // 2d = distance between P1 and P2
        double A = 0.5 * (r2 - r1); // SMA of hyperbola through F1 with P1 or P2 as focus
        double E = d / A;           // ecc of hyperbola through F1 with P1 or P2 as focus
        double B = Math.sqrt(Math.pow(d, 2) - Math.pow(A, 2)); // semi-minor axis of hyperbola through F1 with P1 or P2 as focus
        double x0 = -rm / E;
        double y0 = B * Math.sqrt(Math.pow(x0 / A, 2) - 1);
        
        // temporary variables - dependent on y
        double x = A * Math.sqrt(1 + Math.pow(y / B, 2));
        
        double x0_min_x2 = Math.pow(x0 - x, 2);
        double y0_min_y2 = Math.pow(y0 - y, 2);
        double sqrt_x0_min_x2_plus_y0_min_y2 = Math.sqrt(x0_min_x2 + y0_min_y2);
        
        double fx = (x0 - x) / sqrt_x0_min_x2_plus_y0_min_y2;
        double fy = (y0 - y) / sqrt_x0_min_x2_plus_y0_min_y2;
        
        double val_to_asin = (((x0 + d) * fy) - ( y0 * fx)) / r1;
        if (Utils.sin(alpha) < 0) {
            val_to_asin = -val_to_asin;
        }
        
        // outputs
        double a = 0.5 * (rm + (E * x));                    // SMA of transfer ellipse
        double e = sqrt_x0_min_x2_plus_y0_min_y2 / (2 * a); // ecc of transfer ellipse
        
        // TODO - decide how to get the true true anomaly
        double ta1 = Math.acos(-(((x0 + d) * fx) + (y0 * fy)) / r1);
        double ta1_viasin = Math.asin(val_to_asin);
        double ta1_gtb = Math.acos(((a * (1 - Math.pow(e,2))) - r1) / (e * r1));
        
        System.out.println("a: " + OrbitUtils.distanceToString(a));
        System.out.println("e: " + Utils.roundToDP(e, 5));
        System.out.println("ta1: " + Utils.roundToDP(Math.toDegrees(ta1), 1) + " gives r: " + OrbitUtils.distanceToString(OrbitUtils.radiusAtTrueAnomaly(a, e, ta1)));
        System.out.println("ta1_viasin: " + Utils.roundToDP(Math.toDegrees(ta1_viasin), 1) + " gives r: " + OrbitUtils.distanceToString(OrbitUtils.radiusAtTrueAnomaly(a, e, ta1_viasin)));
        System.out.println("ta1_gtb: " + Utils.roundToDP(Math.toDegrees(ta1_gtb), 1) + " gives r: " + OrbitUtils.distanceToString(OrbitUtils.radiusAtTrueAnomaly(a, e, ta1_gtb)));
        
        double alpha_rad = Math.toRadians(alpha);
        double ta2 = ta1 + alpha_rad;
        double ta2_viasin = ta1_viasin + alpha_rad;
        double ta2_gtb = ta1_gtb + alpha_rad;
        System.out.println("ta2: " + Utils.roundToDP(Math.toDegrees(ta2), 1) + " gives r: " + OrbitUtils.distanceToString(OrbitUtils.radiusAtTrueAnomaly(a, e, ta2)));
        System.out.println("ta2_viasin: " + Utils.roundToDP(Math.toDegrees(ta2_viasin), 1) + " gives r: " + OrbitUtils.distanceToString(OrbitUtils.radiusAtTrueAnomaly(a, e, ta2_viasin)));
        System.out.println("ta2_gtb: " + Utils.roundToDP(Math.toDegrees(ta2_gtb), 1) + " gives r: " + OrbitUtils.distanceToString(OrbitUtils.radiusAtTrueAnomaly(a, e, ta2_gtb)));
        
        // TODO - do we want to convert these details into an Orbit object (or something similar)?
        // TODO - calculate transfer time, compare to desired arrival time - the solution is only useful if the target body will be there!
        double period = OrbitUtils.orbitalPeriod(a, pmu);
        System.out.println("Period of calculated ellipse: " + Utils.getDurationString(period));
        
        double tt = OrbitUtils.secondsToTA(a, e, pmu, ta1, ta2);
        double tt_viasin = OrbitUtils.secondsToTA(a, e, pmu, ta1_viasin, ta2_viasin);
        double tt_gtb = OrbitUtils.secondsToTA(a, e, pmu, ta1_gtb, ta2_gtb);
        
        System.out.println("tt: " + Utils.roundToDP(tt, 0));
        System.out.println("tt_viasin: " + Utils.roundToDP(tt_viasin, 0));
        System.out.println("tt_gtb: " + Utils.roundToDP(tt_gtb, 0));
    }
}
