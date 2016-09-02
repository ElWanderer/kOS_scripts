@LAZYGLOBAL OFF.
pOut("lib_crew.ks v1.1.1 20160902").

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
  PARAMETER c IS SHIP.
  RETURN c:CREW():LENGTH.
}

FUNCTION crewSpaces
{
  PARAMETER c IS SHIP.
  RETURN c:CREWCAPACITY - crewCount(c).
}

FUNCTION printCrew
{
  PARAMETER c IS SHIP.
  IF crewCount(c) > 0 {
    pOut("Crew details:").
    FOR kerb IN c:CREW() {
      LOCAL role IS "Tourist".
      IF NOT kerb:TOURIST { SET role TO kerb:TRAIT. }
      pOut(role + " " + kerb:NAME + " in " + kerb:PART:TITLE).
    }
  }
  pOut("Vacant seats: " + crewSpaces()).
}
