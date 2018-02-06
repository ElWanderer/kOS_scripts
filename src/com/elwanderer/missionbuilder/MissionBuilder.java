package com.elwanderer.missionbuilder;

import java.io.*;
import java.awt.*;
import java.awt.event.*;
import javax.swing.*;
import javax.swing.SwingUtilities;

public class MissionBuilder extends JPanel implements ActionListener {
	
    static private final String newline = "\n";
    JButton openButton;
    JTextArea log;
    JFileChooser fc;
	
	public MissionBuilder() {
		super(new BorderLayout());
 
        //Create the log first, because the action listeners
        //need to refer to it.
        log = new JTextArea(5,20);
        log.setMargin(new Insets(5,5,5,5));
        log.setEditable(false);
        JScrollPane logScrollPane = new JScrollPane(log);
 
        //Create a file chooser
        fc = new JFileChooser();
        fc.setFileSelectionMode(JFileChooser.FILES_AND_DIRECTORIES);
 
        //Create the open button.
        openButton = new JButton("Open a File...");
        openButton.addActionListener(this);
 
        //For layout purposes, put the buttons in a separate panel
        JPanel buttonPanel = new JPanel(); //use FlowLayout
        buttonPanel.add(openButton);
 
        //Add the buttons and the log to this panel.
        add(buttonPanel, BorderLayout.PAGE_START);
        add(logScrollPane, BorderLayout.CENTER);
	}
	
    public void actionPerformed(ActionEvent e) {
    	 
        //Handle open button action.
        if (e.getSource() == openButton) {
            int returnVal = fc.showOpenDialog(MissionBuilder.this);
 
            if (returnVal == JFileChooser.APPROVE_OPTION) {
                File file = fc.getSelectedFile();
                
                log.append("Opening: " + file.getName() + "." + newline);
                KSPSaveFileReader sfr = new KSPSaveFileReader();
        		
                try {
                	sfr.LoadKSPSave(file.getPath());
                } catch (IOException ex) {
                	log.append("Error opening: " + file.getName() + "." + newline);
                }
            }
            log.setCaretPosition(log.getDocument().getLength());
        }
    }
    
    private static void createAndShowGUI() {
        //Create and set up the window.
        JFrame frame = new JFrame("Mission Builder");
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
 
        //Add content to the window.
        frame.add(new MissionBuilder());
 
        //Display the window.
        frame.pack();
        frame.setVisible(true);
    }

	public static void main(String[] args) throws IOException {

		SwingUtilities.invokeLater(new Runnable() {
            public void run() {
                //Turn off metal's use of bold fonts
                UIManager.put("swing.boldMetal", Boolean.FALSE); 
                createAndShowGUI();
            }
        });
        
		/*
		KSPSaveFileReader sfr = new KSPSaveFileReader();
		String path = "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Kerbal Space Program v1.3.1\\saves\\Geoff_1_3_1-Career\\persistent_copy.sfs";
		sfr.LoadKSPContracts(path);
		*/
		
		/*
		double time = 103208329.879951;
		// time 103208329.879951
		// should produce:
		// Kerbin 256.940169
		// Moho    42.281699
		// Gilly  214.474665
		// Bop    225.709018
		// Pol    200.154879
		// Jool     0.809396
		KSPSolarSystem system = new KSPSolarSystem();
		//System.out.println(system.toString());
		KSPCelestialBody kerbin = system.getBodyByName("KERBIN");
		KSPCelestialBody moho = system.getBodyByName("MOHO");
		KSPCelestialBody gilly = system.getBodyByName("GILLY");
		KSPCelestialBody bop = system.getBodyByName("BOP");
		KSPCelestialBody pol = system.getBodyByName("POL");
		KSPCelestialBody jool = system.getBodyByName("JOOL");
		//KSPCelestialBody testBody = system.getBodyByName("TEST");
		double tak = OrbitUtils.trueAnomalyAtTime(kerbin, time);
		System.out.println("Kerbin's true anomaly = " + tak);
		double tam = OrbitUtils.trueAnomalyAtTime(moho, 1283646);
		System.out.println("Moho's true anomaly = " + tam);
		//System.out.println("Moho's period = " + moho.getPeriod());
		double tag = OrbitUtils.trueAnomalyAtTime(gilly, time);
		System.out.println("Gilly's true anomaly = " + tag);
		//System.out.println("Gilly's period = " + gilly.getPeriod());
		double tab = OrbitUtils.trueAnomalyAtTime(bop, time);
		System.out.println("Bop's true anomaly = " + tab);
		double tap = OrbitUtils.trueAnomalyAtTime(pol, time);
		System.out.println("Pol's true anomaly = " + tap);
		double taj = OrbitUtils.trueAnomalyAtTime(jool, time);
		System.out.println("Jool's true anomaly = " + taj);
		*/
	}
}
