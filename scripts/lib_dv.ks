@LAZYGLOBAL OFF.
pOut("lib_dv.ks v1.1.0 20170814").

RUNONCEPATH(loadScript("lib_parts.ks")).
GLOBAL DV_PL IS LIST().
GLOBAL DV_FM IS 0.
GLOBAL DV_ISP IS 0.
GLOBAL DV_FR IS 0.
GLOBAL DV_FUELS IS LIST("LiquidFuel","Oxidizer").
F_POST_STAGE:ADD(setIspFuelRate@).
F_POST_STAGE:ADD(pDV@).

setIspFuelRate().
IF SHIP:AVAILABLETHRUST > 0 { pDV(). }

FUNCTION fuelRate
{
  PARAMETER t,i.
  IF i > 0 { RETURN t / (i * g0). }
  ELSE { RETURN 0. }
}

FUNCTION btCalc
{
  PARAMETER dv, m0, i, fr.
  IF i > 0 AND fr > 0 {
    LOCAL m1 IS m0 / (CONSTANT:E^(dv / (g0 * i))).
    RETURN (m0 -  m1) / fr.
  } ELSE { RETURN 0. }
}

FUNCTION partMass
{
  PARAMETER p.
  LOCAL m IS p:MASS.
  FOR cp IN p:CHILDREN { SET m TO m + partMass(cp). }
  RETURN m.
}

FUNCTION engCanFire
{
  PARAMETER e.
  RETURN NOT e:IGNITION AND e:ALLOWRESTART AND e:ALLOWSHUTDOWN.
}

FUNCTION moreEngines
{
  LOCAL all_e IS LIST().
  LIST ENGINES IN all_e.
  FOR e IN all_e { IF engCanFire(e) { RETURN TRUE. } }
  RETURN FALSE.
}

FUNCTION currentStageEngines
{
  LOCAL el IS LIST().
  LOCAL all_e IS LIST().
  LIST ENGINES IN all_e.
  FOR e IN all_e { IF e:IGNITION AND NOT e:FLAMEOUT { el:ADD(e). } }
  RETURN el.
}

FUNCTION nextStageBT
{
  PARAMETER dv.
  LOCAL bt IS 0.

  LOCK THROTTLE TO 0. WAIT 0.

  LOCAL min_mass IS 9999.
  LOCAL all_e IS LIST().
  LIST ENGINES IN all_e.

  LOCAL ne IS all_e[0].
  LOCAL ok IS FALSE.
  FOR e IN all_e { IF engCanFire(e) {
    LOCAL child_mass IS partMass(e) - e:MASS.
    IF child_mass < min_mass AND child_mass > 0 {
      SET min_mass TO child_mass.
      SET ne TO e.
      SET ok TO TRUE.
    }
  }}

  LOCAL m0 IS MASS - min_mass.
  IF ok {
    ne:ACTIVATE. WAIT 0.
    SET bt TO btCalc(dv,m0,ne:VISP,fuelRate(ne:AVAILABLETHRUST,ne:VISP)).
    ne:SHUTDOWN. WAIT 0.
  }

  RETURN bt.
}

FUNCTION setIspFuelRate
{
  PARAMETER limiter IS 1.
  SET DV_ISP TO 0.
  SET DV_FR TO 0.
  LOCAL t IS 0.
  LOCAL t_over_isp IS 0.

  FOR eng IN currentStageEngines() {
    LOCAL e_isp IS eng:ISP.
    LOCAL e_t IS eng:AVAILABLETHRUST * limiter.
    SET t TO t + e_t.
    SET t_over_isp TO t_over_isp + (e_t / e_isp).
    SET DV_FR TO DV_FR + fuelRate(e_t,e_isp).
  }
  IF t_over_isp > 0 { SET DV_ISP TO t / t_over_isp. }
}

FUNCTION fuelMass
{
  PARAMETER rl, fl IS DV_FUELS.
  LOCAL m IS 0.
  FOR r IN rl { IF fl:CONTAINS(r:NAME) { SET m TO m + (r:AMOUNT * r:DENSITY). } }
  RETURN m.
}

FUNCTION fuelMassChildren
{
  PARAMETER p.
  IF NOT (isDecoupler(p) OR DV_PL:CONTAINS(p:UID)) {
    DV_PL:ADD(p:UID).
    SET DV_FM TO DV_FM + fuelMass(p:RESOURCES).
    FOR cp IN p:CHILDREN { fuelMassChildren(cp). }
  }
}

FUNCTION fuelMassFamily
{
  PARAMETER p.
  FOR cp IN p:CHILDREN { fuelMassChildren(cp). }
  IF NOT (isDecoupler(p) OR DV_PL:CONTAINS(p:UID)) {
    DV_PL:ADD(p:UID).
    SET DV_FM TO DV_FM + fuelMass(p:RESOURCES).
    IF p:HASPARENT { fuelMassFamily(p:PARENT). }
  }
}

FUNCTION stageDV
{
  PARAMETER recalc_isp IS FALSE.
  IF recalc_isp { setIspFuelRate(). }
  DV_PL:CLEAR.
  SET DV_FM TO 0.
  FOR e IN currentStageEngines() { fuelMassFamily(e). }
  SET DV_FM TO MAX(DV_FM,fuelMass(STAGE:RESOURCES)).
  IF DV_FM = 0 AND SHIP:AVAILABLETHRUST > 0 { SET DV_FM TO fuelMass(SHIP:RESOURCES). }
  RETURN (g0 * DV_ISP * LN(MASS / (MASS-DV_FM))).
}

FUNCTION pDV
{
  pOut("Stage delta-v: " + ROUND(stageDV(),1) + "m/s.").
}

FUNCTION burnTime
{
  PARAMETER dv, sdv IS stageDV(), limiter IS 1, recalc_isp IS FALSE.
  IF recalc_isp { setIspFuelRate(limiter). }
  LOCAL bt IS btCalc(dv,MASS,DV_ISP,DV_FR).
  IF dv > sdv {
    LOCAL bt1 IS btCalc(sdv,MASS,DV_ISP,DV_FR).
    LOCAL bt2 IS nextStageBT(dv - sdv).
    IF bt2 = 0 { SET bt2 TO (bt - bt1) * 2.5. }
    RETURN bt1 + bt2 + 0.5.
  }
  RETURN bt.
}
