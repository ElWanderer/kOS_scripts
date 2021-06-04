@LAZYGLOBAL OFF.

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("test_slope.ks v1.0.0 20170601").

RUNONCEPATH(loadScript("lib_slope.ks")).

FUNCTION pInstructions {
  pOut("Hit RCS (R) to draw slopes near the vessel.").
  pOut("Hit SAS (T) to find a low-slope area near the vessel.").
}

ON RCS {
  // draw slope angles near the vessel
  drawSlopesNearCraft(5, 11).
  pInstructions().
  PRESERVE.
}

ON SAS {
  findLowSlope().
  pInstructions().
  PRESERVE.
}

pInstructions().

WAIT UNTIL FALSE.

