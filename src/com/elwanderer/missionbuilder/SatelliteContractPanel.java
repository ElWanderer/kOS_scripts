package com.elwanderer.missionbuilder;

import java.awt.LayoutManager;
import java.util.ArrayList;
import java.util.Vector;
import javax.swing.JButton;
import javax.swing.JPanel;

public class SatelliteContractPanel extends JPanel {
    
    private boolean initialised = false;
    private ArrayList<JButton> buttons;
    private Vector<KSPSatelliteContract> contracts;

    public SatelliteContractPanel() {
        // TODO Auto-generated constructor stub
    }

    public SatelliteContractPanel(LayoutManager arg0) {
        super(arg0);
        // TODO Auto-generated constructor stub
    }

    public SatelliteContractPanel(boolean arg0) {
        super(arg0);
        // TODO Auto-generated constructor stub
    }

    public SatelliteContractPanel(LayoutManager arg0, boolean arg1) {
        super(arg0, arg1);
        // TODO Auto-generated constructor stub
    }

    public void initialiseContracts(KSPGameState gameState) {
        contracts = gameState.getSatelliteContracts();
        
        for (KSPSatelliteContract contract : contracts) {
            
            System.out.println(contract.toString());
            //JButton contractButton = new JButton();
            
            //buttons.add(contractButton);
        }
        
        initialised = true;
    }
}
