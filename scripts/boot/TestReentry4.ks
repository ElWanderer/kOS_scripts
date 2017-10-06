@LAZYGLOBAL OFF.

// TestReentry4.ks
//
// TBD

IF NOT EXISTS("1:/init.ks") { RUNPATH("0:/init_select.ks"). }
RUNONCEPATH("1:/init.ks").

pOut("TestReentry4.ks v1.0.0 20171006").

FOR f IN LIST(
  "lib_runmode.ks",
  "lib_steer.ks",
  "lib_orbit_match.ks",
  "lib_launch_common.ks",
  "plot_reentry.ks",
  "plot_transfer_reentry.ks",
  "lib_reentry.ks"
) { RUNONCEPATH(loadScript(f)). }

// set these values ahead of launch
GLOBAL SAT_NAME IS "Reentry Test4 11".

GLOBAL REENTRY_LEX IS LEXICON().
GLOBAL REENTRY_LOG_FILE IS "0:/log/TestReentry7.txt".
GLOBAL REENTRY_CSV_FILE IS "0:/log/TestReentry6.csv".
GLOBAL REENTRY_CRAFT_FILE IS "0:/craft/" + padRep(0,"_",SAT_NAME) + ".ks".

IF runMode() > 0 { logOn(). }

UNTIL runMode() = 99 {
LOCAL rm IS runMode().
IF rm < 0 {
  SET SHIP:NAME TO SAT_NAME.
  logOn().
  killThrot().

  hudMsg("Hit abort to trigger landing when ready.").
  runMode(809,801).

} ELSE IF rm < 50 {
  resume().

} ELSE IF rm > 50 AND rm < 99 {
  resume().

} ELSE IF rm > 100 AND rm < 150 {
  resume().

} ELSE IF MOD(rm,10) = 9 AND rm > 800 AND rm < 999 {
  hudMsg("Error state. Hit abort to switch to recovery mode: " + abortMode() + ".").
  steerSun().
  WAIT UNTIL MOD(runMode(),10) <> 9.

} ELSE IF rm = 801 {
  killWarp().
  UNTIL SHIP:MAXTHRUST > 0 { doStage(). WAIT 1. }

  store("doTransfer(861, FALSE, KERBIN, 30000, -1, -1, "+CHAR(34)+REENTRY_LOG_FILE+CHAR(34)+").").
  doTransfer(861, FALSE, KERBIN, 30000, -1, -1, REENTRY_LOG_FILE).

} ELSE IF rm = 861 {
  SET REENTRY_LEX TO plotReentry(REENTRY_LOG_FILE).
  store("doReentry(1,871).").
  doReentry(1,871).

} ELSE IF rm = 871 {
  logReentry(REENTRY_LOG_FILE, REENTRY_CSV_FILE, REENTRY_LEX).
  runMode(99).
}

}
