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
    JButton viewMapButton;
    JButton viewContractsButton;
    JLabel saveFileLabel;
    JLabel calendarLabel;
    JTextArea log;
    JFileChooser fc;
    
    KSPGameState gameState;
    boolean saveLoaded = false;
	
	public MissionBuilder() {
		super(new BorderLayout());
 
        //Create the log first, because the action listeners
        //need to refer to it.
        log = new JTextArea(3,20);
        log.setMargin(new Insets(5,5,5,5));
        log.setEditable(false);
        log.setBackground(Color.LIGHT_GRAY);
        JScrollPane logScrollPane = new JScrollPane(log);
        
        saveFileLabel = new JLabel("");
        saveFileLabel.setPreferredSize(new Dimension(850, 25));
        saveFileLabel.setHorizontalAlignment(SwingConstants.LEFT);
        
        calendarLabel = new JLabel("");
        calendarLabel.setPreferredSize(new Dimension(150, 25));
        calendarLabel.setHorizontalAlignment(SwingConstants.RIGHT);
 
        //Create a file chooser
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
 
        //Create the open button.
        openButton = new JButton("Open a File...");
        openButton.addActionListener(this);

        //Create the open button.
        viewMapButton = new JButton("View Map");
        viewMapButton.addActionListener(this);
        
        //Create the open button.
        viewContractsButton = new JButton("View Contracts");
        viewContractsButton.addActionListener(this);
        
        refreshButtonStates();
        
        //For layout purposes, put the buttons in a separate panel
        JPanel buttonPanel = new JPanel(); //use FlowLayout
        buttonPanel.add(openButton);
        buttonPanel.add(viewMapButton);
        buttonPanel.add(viewContractsButton);
        
        JPanel summaryPanel = new JPanel(); //use FlowLayout
        summaryPanel.add(saveFileLabel);
        summaryPanel.add(calendarLabel);
        
        JPanel mainPanel = new JPanel();
        JLabel tempMainLabel = new JLabel("Main content here");
        mainPanel.setPreferredSize(new Dimension(1000,500));
        mainPanel.setBackground(Color.WHITE);
        mainPanel.add(tempMainLabel);
        
        JPanel mainWindow = new JPanel(new BorderLayout());
        mainWindow.add(summaryPanel, BorderLayout.PAGE_START);
        mainWindow.add(mainPanel, BorderLayout.CENTER);
        
        //Add the buttons and the log to this panel.
        add(buttonPanel, BorderLayout.PAGE_START);
        add(mainWindow, BorderLayout.CENTER);
        add(logScrollPane, BorderLayout.PAGE_END);
	}
	
	private void refreshButtonStates() {
		viewMapButton.setEnabled(saveLoaded);
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
    	 
        //Handle open button action.
        if (e.getSource() == openButton) {
            int fileChooserOption = fc.showOpenDialog(MissionBuilder.this);
 
            if (fileChooserOption == JFileChooser.APPROVE_OPTION) {
                File file = fc.getSelectedFile();
                
                log.append("Opening: " + file.getName() + "." + newline);
                KSPSaveFileReader sfr = new KSPSaveFileReader();
        		
                try {
                	gameState = sfr.LoadKSPSave(file.getPath());
                } catch (IOException ex) {
                	log.append("Error opening: " + file.getName() + "." + newline);
                }
            }
            log.setCaretPosition(log.getDocument().getLength());
            
            saveLoaded = (gameState != null);
            refreshButtonStates();
            refreshSummaryPanel();
        } else if (e.getSource() == viewMapButton) {
        	// TODO
        } else if (e.getSource() == viewContractsButton) {
        	// TODO
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
