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
	
	public boolean LoadKSPContracts(String path) throws IOException {
		boolean returnVal = false;
		
		Scanner saveFileReader = null;
		
		try {
			boolean ok = true;
			saveFileReader = new Scanner(new BufferedReader(new FileReader(path)));
			
			while (ok) {
			    KSPConfigBlock block = ReadNamedBlock(saveFileReader, "CONTRACT");
			    if (block != null) {
			    	if (block.getStringField("type").equals("SatelliteContract")) {
				    	KSPSatelliteContract con = new KSPSatelliteContract(block);
				    	System.out.println(con.toString());
			    	}

			    } else {
			    	ok = false;
			    }
			}

		} finally {
			if (saveFileReader != null) {
				saveFileReader.close();
			}
		}
		
		return returnVal;
	}
}
