@LAZYGLOBAL OFF.
pOut("lib_crew.ks v1.1.0 20160725").

GLOBAL CREW_SIZE IS 0.
GLOBAL CREW_FN IS "cs.ks".

resume(CREW_FN).

FUNCTION updateLastCrewCount
{
  SET CREW_SIZE TO crewCount().
  store("SET CREW_SIZE TO " + CREW_SIZE + ".", CREW_FN, 50).
}

FUNCTION lastCrewCount
{
  RETURN CREW_SIZE.
}

FUNCTION crewCount
{
  PARAMETER v IS SHIP.
  RETURN v:CREW():LENGTH.
}

FUNCTION crewSpaces
{
  PARAMETER v IS SHIP.
  RETURN v:CREWCAPACITY - crewCount(v).
}

FUNCTION printCrew
{
  PARAMETER v IS SHIP.
  IF crewCount(v) > 0 {
    pOut("Crew details:").
    FOR kerb IN v:CREW() {
      LOCAL role IS "".
      IF kerb:TOURIST { SET role TO "Tourist". }
      ELSE { SET role TO kerb:TRAIT. }
      LOCAL pod IS kerb:PART:NAME.
      pOut("    " + role + " " + kerb:NAME + " in " + pod).
    }
  }
  pOut("Crew spaces vacant: " + crewSpaces()).
}