package com.elwanderer.missionbuilder;

import java.io.*;
import java.util.*;

public class KSPSaveFileReader {

	static boolean ScanForExactString(Scanner s, String content) {
		boolean found = false;
		while (!found && s.hasNext()) {
			String line = s.nextLine().trim();
			if (line.equals(content)) {
				found = true;
			}
		}
		return found;
	}
	
	public KSPSaveFileReader() {
		// TODO Auto-generated constructor stub
	}
	
	public KSPConfigBlock ReadNamedBlock(Scanner s, String n) {
		
		KSPConfigBlock b = null;
		if (ScanForExactString(s, n)) {
			b = new KSPConfigBlock(n,0); // braceCount is 0 as we will pick up the first one when we scan on from the name
			b.ReadBlock(s);
		}
		return b;
	}
	
	public KSPGameState LoadKSPSave(String path) throws IOException {

		String gameSaveFileName = path;
		KSPGameState gameState = null;
		Scanner saveFileReader = null;
		
		try {
			
			boolean readOk = true;
			double gameSaveTime = 0.0;
			Vector<KSPSatelliteContract> gameSatelliteContracts = new Vector<KSPSatelliteContract>();
			
	    	System.out.println("Reading in save file: " + path);
	    	System.out.println("");
			
			// read in flight state - get current game time
			saveFileReader = new Scanner(new BufferedReader(new FileReader(path)));
			KSPConfigBlock flightStateBlock = ReadNamedBlock(saveFileReader, "FLIGHTSTATE");
		    if (readOk && flightStateBlock != null) {
		    	gameSaveTime = flightStateBlock.getDoubleField("UT");
		    	System.out.println("Current game time (UT): " + gameSaveTime);
		    	System.out.println("Current game time: " + Utils.getTimeString(gameSaveTime));
		    	System.out.println("");
		    } else {
		    	readOk = false;
		    }
		    
		    // read in contracts
		    if (readOk)
		    {
				boolean readContractBlock = true;
				saveFileReader = new Scanner(new BufferedReader(new FileReader(path)));
				while (readContractBlock) {
				    KSPConfigBlock contractBlock = ReadNamedBlock(saveFileReader, "CONTRACT");
				    if (contractBlock != null) {
				    	if (contractBlock.getStringField("type").equals("SatelliteContract")) {
					    	KSPSatelliteContract con = new KSPSatelliteContract(contractBlock);
					    	System.out.println(con.toString());
					    	gameSatelliteContracts.add(con);
				    	}

				    } else {
				    	readContractBlock = false;
				    }
				}		    	
		    }
			
			if (readOk) {
				System.out.println("File read successfully");
				gameState = new KSPGameState(gameSaveFileName, gameSaveTime, gameSatelliteContracts);
			} else {
				System.out.println("File not read successfully");
			}

		} finally {
			if (saveFileReader != null) {
				saveFileReader.close();
			}
		}
		
		return gameState;
	}
}
