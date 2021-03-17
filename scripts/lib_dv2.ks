@LAZYGLOBAL OFF.
pOut("lib_dv.ks v2.0.0 20210317").

RUNONCEPATH(loadScript("lib_parts.ks")).

GLOBAL DV_PL IS LIST(). // visited parts list
GLOBAL DV_ACTIVE_ENGINES IS LIST().
GLOBAL DV_NEEDED_FUELS IS LEXICON().
GLOBAL DV_AVAILABLE_FUEL IS LEXICON().
GLOBAL DV_FR IS 0.
GLOBAL DV_ISP IS 0.

F_POST_STAGE:ADD(resetDVValues@).
F_POST_STAGE:ADD(pDV@).

resetDVValues().
IF SHIP:AVAILABLETHRUST > 0 { pDV(). }

FUNCTION resetDVValues
{
  setActiveEngines().
}

FUNCTION currentThrust
{
  LOCAL t IS 0.
  FOR eng IN DV_ACTIVE_ENGINES { SET t TO t + eng:THRUST. }
  RETURN t.
}

FUNCTION currentTWR
{
  RETURN currentThrust() / (g0 * SHIP:MASS).
}

FUNCTION pTWR
{
  pOut("Current TWR: " + ROUND(currentTWR(),2)).
}

FUNCTION engCanFire
{
  PARAMETER e, as IS FALSE.
  RETURN (NOT e:IGNITION) AND (as OR (e:ALLOWRESTART AND e:ALLOWSHUTDOWN)).
}

FUNCTION moreEngines
{
  PARAMETER as IS FALSE.
  LOCAL all_e IS LIST().
  LIST ENGINES IN all_e.
  FOR e IN all_e { IF engCanFire(e,as) AND e:STAGE < STAGE:NUMBER AND NOT stageIsFinal(e:STAGE) { RETURN TRUE. } }
  RETURN FALSE.
}

FUNCTION btCalc
{
  PARAMETER dv, m0, i, fr.
  IF i > 0 AND fr > 0 {
    LOCAL m1 IS m0 / (CONSTANT:E^(dv / (g0 * i))).
    RETURN (m0 -  m1) / fr.
  } ELSE { RETURN 0. }
}

FUNCTION addFuelToLex
{
  PARAMETER fuelLexicon, fuelName, fuelAmount.
  IF NOT fuelLexicon:HASKEY(fuelName) {
    fuelLexicon:ADD(fuelName, fuelAmount).
  } ELSE {
    SET fuelLexicon[fuelName] TO fuelLexicon[fuelName] + fuelAmount.
  }
}

FUNCTION addResourcesToLex
{
  PARAMETER p, fuelLexicon.
  FOR r IN p:RESOURCES {
    IF r:DENSITY > 0 AND r:AMOUNT > 0 AND (NOT r:TOGGLEABLE OR r:ENABLED) {
      addFuelToLex(fuelLexicon, r:NAME, (r:AMOUNT * r:DENSITY)).
    }
  }
}

FUNCTION fuelMassChildren
{
  PARAMETER p, fuelLexicon.
  IF NOT (isBlockingDecoupler(p) OR DV_PL:CONTAINS(p:UID)) {
    DV_PL:ADD(p:UID).
    addResourcesToLex(p, fuelLexicon).
    FOR cp IN p:CHILDREN { fuelMassChildren(cp, fuelLexicon). }
  }
  IF NOT DV_PL:CONTAINS(p:UID) { DV_PL:ADD(p:UID). }
}

FUNCTION fuelMassFamily
{
  PARAMETER p, fuelLexicon.
  FOR cp IN p:CHILDREN { fuelMassChildren(cp, fuelLexicon). }
  IF NOT (isBlockingDecoupler(p) OR DV_PL:CONTAINS(p:UID)) {
    DV_PL:ADD(p:UID).
    addResourcesToLex(p, fuelLexicon).
    IF p:HASPARENT { fuelMassFamily(p:PARENT, fuelLexicon). }
  }
  IF NOT DV_PL:CONTAINS(p:UID) { DV_PL:ADD(p:UID). }
}

FUNCTION setActiveEngines
{
  DV_NEEDED_FUELS:CLEAR().
  SET DV_ISP TO 0.
  SET DV_FR TO 0.
  LOCAL total_thrust IS 0.
  LOCAL el IS LIST().
  LOCAL all_e IS LIST().
  LIST ENGINES IN all_e.
  FOR e IN all_e { IF e:IGNITION AND NOT e:FLAMEOUT AND e:THRUSTLIMIT > 0 {
    el:ADD(e).
    SET total_thrust TO total_thrust + e:AVAILABLETHRUST.
    LOCAL all_consumed_resources IS e:CONSUMEDRESOURCES.
    LOCAL engine_needs_multiple_fuels IS (all_consumed_resources:LENGTH > 1).
    FOR cr IN all_consumed_resources:VALUES {
      //LOCAL fuelRatio IS CHOOSE ROUND(cr:RATIO,5) IF engine_needs_multiple_fuels ELSE 1. // TODO - needed?
      LOCAL fuelMassFlow IS cr:MAXMASSFLOW * e:THRUSTLIMIT / 100.
      // TODO - should we store the required fuel and/or mass flow for each engine?
      pOut(e:NAME + " requires " + ROUND(fuelMassFlow*1000,1) + "kg/s of " + cr:NAME).
      addFuelToLex(DV_NEEDED_FUELS, cr:NAME, fuelMassFlow).
      SET DV_FR TO DV_FR + fuelMassFlow.
    }
  } }
  SET DV_ISP TO CHOOSE 0 IF DV_FR = 0 ELSE (total_thrust / (DV_FR*g0)).
pOut("Total thrust: " + ROUND(total_thrust,1) + "kN").
pOut("Total fuel mass flow: " + ROUND(DV_FR, 3) + "t/s").
pOut("Resultant Isp: " + ROUND(DV_ISP,1) + "s").
  SET DV_ACTIVE_ENGINES TO el:COPY.
  
  FOR fuelName IN DV_NEEDED_FUELS:KEYS {
    LOCAL fuelMassFlow IS DV_NEEDED_FUELS[fuelName].
    pOut("Current stage requires " + ROUND(fuelMassFlow*1000,1) + "kg/s of " + fuelName).
  }
}

FUNCTION fuelDelta
{
  PARAMETER fuelAvailableLex, fuelNeededLex.
  LOCAL fuelMass IS 0.
  LOCAL minFuelTime IS 0.
  
  FOR fuelName IN fuelNeededLex:KEYS {
    pOut("Checking fuel: " + fuelName).
    IF fuelAvailableLex:HASKEY(fuelName) {
      LOCAL fuelTime IS fuelAvailableLex[fuelName] / fuelNeededLex[fuelName].
      pOut("Fuel for " + ROUND(fuelTime, 1) + "s").
      SET minFuelTime TO CHOOSE fuelTime IF minFuelTime = 0 ELSE MIN(minFuelTime, fuelTime).
    } ELSE {
      pOut("No fuel available").
      RETURN 0.
    }
  }
  
  FOR fuelName IN fuelAvailableLex:KEYS {
    IF fuelNeededLex:HASKEY(fuelName) {
      SET fuelMass TO fuelMass + (minFuelTime * fuelNeededLex[fuelName]).
    }
  }
  pOut("Total fuel delta: " + ROUND(fuelMass,3) + "t").
  RETURN fuelMass.
}

FUNCTION stageDV
{
  PARAMETER recalc_isp IS FALSE.
  IF recalc_isp { resetDVValues(). }
  
  DV_PL:CLEAR().
  DV_AVAILABLE_FUEL:CLEAR().
  FOR e IN DV_ACTIVE_ENGINES { fuelMassFamily(e, DV_AVAILABLE_FUEL). }
  
  RETURN (g0 * DV_ISP * LN(MASS / (MASS-fuelDelta(DV_AVAILABLE_FUEL, DV_NEEDED_FUELS)))).
}

FUNCTION pDV
{
  pOut("Stage delta-v: " + ROUND(stageDV(),1) + "m/s.").
}

FUNCTION burnTime
{
  PARAMETER dv, sdv IS stageDV(), limiter IS 1, recalc_isp IS FALSE.
  IF recalc_isp { resetDVValues(). }
  LOCAL bt IS btCalc(dv,MASS,DV_ISP,DV_FR * limiter).
  IF dv > sdv {
    LOCAL bt1 IS btCalc(sdv,MASS,DV_ISP,DV_FR * limiter).
    LOCAL bt2 IS 0. // TODO - was nextStageBT(dv - sdv).
    IF bt2 = 0 { SET bt2 TO (bt - bt1) * 2.5. }
    RETURN bt1 + bt2 + 0.5.
  }
  RETURN bt.
}


//******************************//
// WORK IN PROGRESS STUFF BELOW //
//******************************//

LOCAL startTime IS TIME:SECONDS.

// TODO - this is an adapation of fuelDelta()
FUNCTION newFuelDelta
{
  PARAMETER fuelAvailableLex, fuelNeededLex.
  LOCAL fuelMass IS 0.
  LOCAL minFuelTime IS -1.
  LOCAL usedFuel IS LEXICON().
  LOCAL excessFuel IS LEXICON().
  
  FOR fuelName IN fuelNeededLex:KEYS {
    pOut("Checking fuel: " + fuelName).
    IF fuelAvailableLex:HASKEY(fuelName) {
      LOCAL fuelTime IS fuelAvailableLex[fuelName] / fuelNeededLex[fuelName].
      pOut("Fuel for " + ROUND(fuelTime, 1) + "s").
      SET minFuelTime TO CHOOSE fuelTime IF minFuelTime = -1 ELSE MIN(minFuelTime, fuelTime).
    } ELSE {
      pOut("No fuel available").
      SET minFuelTime TO 0.
    }
  }
  
  IF minFuelTime = -1 { SET minFuelTime TO 0. }
  
  FOR fuelName IN fuelAvailableLex:KEYS {
    LOCAL massRequired IS 0.
    IF fuelNeededLex:HASKEY(fuelName) {
      SET massRequired TO minFuelTime * fuelNeededLex[fuelName].
      SET fuelMass TO fuelMass + massRequired.
      usedFuel:ADD(fuelName, massRequired).
      PRINT "Used fuel - " + fuelName + " " + ROUND(massRequired,3) + "kg".
    }
    LOCAL availableFuelMass IS fuelAvailableLex[fuelName].
    IF availableFuelMass > (massRequired + 0.001) {
      LOCAL excessFuelMass IS availableFuelMass - massRequired.
      excessFuel:ADD(fuelName, excessFuelMass).
      PRINT "Excess fuel - " + fuelName + " " + ROUND(excessFuelMass,3) + "kg".
    }
  }
  pOut("Total fuel delta: " + ROUND(fuelMass,3) + "t").
  
  LOCAL details IS LEXICON().
  details:ADD("fuelDelta", fuelMass).
  details:ADD("burnTime", minFuelTime).
  details:ADD("usedFuel", usedFuel).
  details:ADD("excessFuel", excessFuel).
  RETURN details.
}

// TODO - this is an adaptation of setActiveEngines()
FUNCTION setStageEngineDetails
{
  PARAMETER el.
  LOCAL total_thrust IS 0.
  LOCAL total_fuel_rate IS 0.
  LOCAL averageIsp IS 99.
  LOCAL neededFuels IS LEXICON().

  FOR e IN el {
    SET total_thrust TO total_thrust + e:POSSIBLETHRUST.
    LOCAL all_consumed_resources IS e:CONSUMEDRESOURCES.
    //LOCAL engine_needs_multiple_fuels IS (all_consumed_resources:LENGTH > 1).
    FOR cr IN all_consumed_resources:VALUES {
      //LOCAL fuelRatio IS CHOOSE ROUND(cr:RATIO,5) IF engine_needs_multiple_fuels ELSE 1. // TODO - needed?
      LOCAL fuelMassFlow IS cr:MAXMASSFLOW * e:THRUSTLIMIT / 100.
      // TODO - should we store the required fuel and/or mass flow for each engine?
      pOut(e:NAME + " requires " + ROUND(fuelMassFlow*1000,1) + "kg/s of " + cr:NAME).
      addFuelToLex(neededFuels, cr:NAME, fuelMassFlow).
      SET total_fuel_rate TO total_fuel_rate + fuelMassFlow.
    }
  }
  SET averageIsp TO CHOOSE 0 IF total_fuel_rate = 0 ELSE (total_thrust / (total_fuel_rate*g0)).
pOut("Total thrust: " + ROUND(total_thrust,1) + "kN").
pOut("Total fuel mass flow: " + ROUND(total_fuel_rate, 3) + "t/s").
pOut("Resultant Isp: " + ROUND(averageIsp,1) + "s").
  
  FOR fuelName IN neededFuels:KEYS {
    LOCAL fuelMassFlow IS neededFuels[fuelName].
    pOut("Stage requires " + ROUND(fuelMassFlow*1000,1) + "kg/s of " + fuelName).
  }
  
  LOCAL detailsLex IS LEXICON().
  detailsLex:ADD("isp", averageIsp).
  detailsLex:ADD("thrust", total_thrust).
  detailsLex:ADD("fuelRate", total_fuel_rate).
  detailsLex:ADD("neededFuels", neededFuels).
  RETURN detailsLex.
}

DV_PL:CLEAR().
LOCAL current_pressure IS 0.
IF BODY:ATM:EXISTS AND ALTITUDE < BODY:ATM:HEIGHT {
  SET current_pressure TO BODY:ATM:ALTITUDEPRESSURE(ALTITUDE).
}
LOCAL highest_stage_number IS -1.
LOCAL stage_info IS LIST().
LOCAL engine_stage_info IS LEXICON().

LOCAL ae IS LIST().
LIST ENGINES IN ae.
FOR e IN ae {
  LOCAL engineOnStage IS e:STAGE.
  LOCAL engineOffStage IS -1.
  
  LOCAL d IS e:DECOUPLER.
  IF d:ISTYPE("STRING") {
    // engine is not decoupled
  } ELSE {
    SET engineOffStage TO d:STAGE.
  }
  
  // only consider engines that are not dropped as they are activated
  IF engineOnStage <> engineOffStage {
    IF engine_stage_info:HASKEY(engineOnStage) {
      LOCAL lex IS engine_stage_info[engineOnStage].
      IF lex:HASKEY("enginesOn") {
        lex["enginesOn"]:ADD(e).
      } ELSE {
        lex:ADD("enginesOn", LIST(e)).
      }
    } ELSE {
      engine_stage_info:ADD(engineOnStage, LEXICON("enginesOn", LIST(e))).
    }
    
    IF engine_stage_info:HASKEY(engineOffStage) {
      LOCAL lex IS engine_stage_info[engineOffStage].
      IF lex:HASKEY("enginesOff") {
        lex["enginesOff"]:ADD(e).
      } ELSE {
        lex:ADD("enginesOff", LIST(e)).
      }
    } ELSE {
      engine_stage_info:ADD(engineOffStage, LEXICON("enginesOff", LIST(e))).
    }
  }
  
  SET highest_stage_number TO MAX(highest_stage_number, MAX(engineOnStage, engineOffStage)).
}

FUNCTION getMassOfParts {
  PARAMETER pl IS DV_PL.
  LOCAL total_mass IS 0.
  LOCAL ap IS LIST().
  LIST PARTS IN ap.
  FOR p IN ap {
    IF pl:CONTAINS(p:UID) {
      SET total_mass TO total_mass + p:MASS.
    }
  }
  RETURN total_mass.
}

FUNCTION getMassOfDecoupledParts {
  PARAMETER stageNumber.
  LOCAL decouplers IS LIST().
  LOCAL total_mass IS 0.
  LOCAL ap IS LIST().
  LIST PARTS IN ap.
  FOR p IN ap {
    IF p:DECOUPLEDIN = stageNumber {
      SET total_mass TO total_mass + p:MASS.
      
      LOCAL d IS p:DECOUPLER.
      IF NOT d:ISTYPE("STRING") {
        IF NOT decouplers:CONTAINS(d) {
          decouplers:ADD(d).
          SET total_mass TO total_mass + d:MASS.
        }
      }
    }
  }
  RETURN total_mass.
}

FUNCTION newStageDV {
  PARAMETER stageIsp, stageWetMass, stageFuelDelta.
  LOCAL dv IS (g0 * stageIsp * LN(stageWetMass / (stageWetMass-stageFuelDelta))).
  PRINT "Stage delta-v: " + ROUND(dv,1) + "m/s".
  RETURN dv.
}

LOCAL stageWetMass IS MASS.
FOR m IN SHIP:MODULESNAMED("LaunchClamp") { IF m:HASEVENT("Release Clamp") {
  SET stageWetMass TO stageWetMass - m:PART:MASS.
}}
PRINT "Vessel mass (less any launch clamps): " + ROUND(stageWetMass,3) + "t".

LOCAL stage_engines IS LIST().
LOCAL previous_stage_leftover_fuel IS LEXICON().

LOCAL stage_number IS highest_stage_number.
UNTIL stage_number < 0 {
  IF engine_stage_info:HASKEY(stage_number) {
PRINT "Stage: " + stage_number.
    LOCAL massDropped IS getMassOfDecoupledParts(stage_number).
PRINT "Mass dropped: " + ROUND(massDropped,3) + "t".
    SET stageWetMass TO stageWetMass - massDropped.
    LOCAL engines_for_stage IS engine_stage_info[stage_number].
    IF engines_for_stage:HASKEY("enginesOff") {
PRINT "Engines dropped:".
      FOR e IN engines_for_stage["enginesOff"] {
PRINT e:NAME + " decoupled by " + e:DECOUPLER:NAME.
        IF stage_engines:CONTAINS(e) { stage_engines:REMOVE(stage_engines:FIND(e)). }
      }
    }
    IF engines_for_stage:HASKEY("enginesOn") {
PRINT "Engines activated:".
      LOCAL eo IS engines_for_stage["enginesOn"].
      FOR e IN eo {
        stage_engines:ADD(e).
PRINT e + " Thrust: " + ROUND(e:POSSIBLETHRUSTAT(current_pressure),1) + "kN Isp: " + ROUND(e:ISPAT(current_pressure),1) + "s".
      }
    }
  }
  
  IF NOT stage_engines:EMPTY {
    LOCAL detailsLex IS setStageEngineDetails(stage_engines).

    LOCAL stage_fuel IS LEXICON().
    FOR e IN stage_engines {
      fuelMassFamily(e, stage_fuel). // note - updates DV_PL so will not consider parts from earlier stages
    }
    LOCAL stageFuelUseDetails IS newFuelDelta(stage_fuel, detailsLex["neededFuels"]).
    LOCAL stageDeltaV IS newStageDV(detailsLex["isp"], stageWetMass, stageFuelUseDetails["fuelDelta"]).
    LOCAL twr IS detailsLex["thrust"] / (stageWetMass * g0).
    PRINT "TWR: " + ROUND(twr, 2).
  }
  
  SET stage_number TO stage_number - 1.
}

PRINT "Elapsed time: " + ROUND(TIME:SECONDS - startTime, 2) + "s".