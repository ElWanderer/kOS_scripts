package com.elwanderer.missionbuilder;

public class KSPContract {

	final String guid;
	final String type;
	final String state;
	final String agent;
	
	public KSPContract(KSPConfigBlock block) {
		guid = block.getStringField("guid");
		type = block.getStringField("type");
		state = block.getStringField("state");
		agent = block.getStringField("agent");
	}

	public String getID() { return guid; }
	
	public String getType() { return type; }
	
	public String getState() { return state; }
	
	public String getAgent() { return agent; }
	
	public boolean isDoable() { return (state.equals("Active") || state.equals("Offered")); }
	
	public String toString() {
		String returnVal = "Contract details:\n\n";
		
		returnVal += "Contract ID: " + guid + "\n";
		returnVal += "Contract type: " + type + "\n";
		returnVal += "Offered by: " + agent + "\n";
		returnVal += "Contract status: " + state + "\n";
		
		return returnVal;
	}
}
