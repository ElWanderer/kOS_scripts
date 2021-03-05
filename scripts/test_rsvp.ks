@LAZYGLOBAL OFF.

RUNONCEPATH("0:/rsvp/main.ks").

LOCAL earliest IS TIME:SECONDS + (60*60*6*0.1).
LOCAL duration IS 60*60*6*360.
LOCAL interval IS duration.

FUNCTION goToBody {
  PARAMETER targetBody IS TARGET, targetPeriapsis IS 100000.
  local options is lexicon(
    "final_orbit_periapsis", targetPeriapsis,
    //"final_orbit_type", "none",
    "final_orbit_orientation", "polar",
    "create_maneuver_nodes", "both",
    "cleanup_maneuver_nodes", FALSE,
    "verbose", TRUE,
    "earliest_departure", earliest,
    "search_duration", duration,
    "search_interval", interval).

  rsvp:goto(targetBody, options).
}

FUNCTION returnToKerbin {
  local options is lexicon(
    "final_orbit_periapsis", 30000,
    "final_orbit_type", "none",
    "create_maneuver_nodes", "both",
    "cleanup_maneuver_nodes", FALSE,
    "verbose", TRUE,
    "earliest_departure", earliest,
    "search_duration", duration,
    "search_interval", interval).

  rsvp:goto(kerbin, options).
}

//goToBody(EELOO, 100000).
returnToKerbin().