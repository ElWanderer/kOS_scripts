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
	
	public boolean LoadKSPSave(String path) throws IOException {
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
			
			saveFileReader = new Scanner(new BufferedReader(new FileReader(path)));
			KSPConfigBlock block = ReadNamedBlock(saveFileReader, "FLIGHTSTATE");
		    if (block != null) {
		    	double time = block.getDoubleField("UT");
		    	System.out.println("Current game time (UT): " + time);
		    	double SECONDS_IN_MINUTE = 60.0;
		    	double SECONDS_IN_HOUR = 60.0 * SECONDS_IN_MINUTE;
		    	double SECONDS_IN_DAY = 6.0 * SECONDS_IN_HOUR;
		    	double SECONDS_IN_YEAR = 426.0 * SECONDS_IN_DAY;
		    	
		    	int years = (int) Math.floor(time / SECONDS_IN_YEAR);
		    	double remain = time - (years * SECONDS_IN_YEAR);
		    	
		    	int days = (int) Math.floor(remain / SECONDS_IN_DAY);
		    	remain -= (days * SECONDS_IN_DAY);
		    	
		    	int hours = (int) Math.floor(remain / SECONDS_IN_HOUR);
		    	remain -= (hours * SECONDS_IN_HOUR);
		    	
		    	int minutes = (int) Math.floor(remain / SECONDS_IN_MINUTE);
		    	remain -= (minutes * SECONDS_IN_MINUTE);
		    	
		    	int seconds = (int) Math.floor(remain);
		    	
		    	System.out.println("Current game time: Y" + (years+1) + " D" + (days+1) + " " + hours + ":" + minutes + ":" + seconds);
		    }

		} finally {
			if (saveFileReader != null) {
				saveFileReader.close();
			}
		}
		
		return returnVal;
	}
}
