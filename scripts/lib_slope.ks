@LAZYGLOBAL OFF.

pOut("lib_slope.ks v1.0.0 20170606").

FOR f IN LIST(
  "lib_geo.ks"
) { RUNONCEPATH(loadScript(f)). }

FUNCTION spotDetails
{
  // returns a list consisting of:
  //  [0]: the position vector for the spot
  //  [1]: the up vector at that spot
  //  [2]: the terrainheight at the spot
  PARAMETER lat, lng.

  LOCAL spot IS LATLNG(lat, lng).
  LOCAL spot_height IS spot:TERRAINHEIGHT.
  LOCAL spot_v IS spot:ALTITUDEPOSITION(spot_height).
  LOCAL up_v IS (spot:ALTITUDEPOSITION(spot_height * 2)-spot_v):NORMALIZED.
  RETURN LIST(spot_v, up_v, spot_height).
}

FUNCTION slopeDetails
{
  // returns a list consisting of:
  //  [0]: the position vector for the spot
  //  [1]: the local up vector
  //  [2]: the terrainheight at the spot
  //  [3]: a normalised vector, pointing normal to the apparent slope
  //  [4]: the angle between [0] and [1]
  //
  // radius is in metres
  PARAMETER lat, lng, radius IS 2.

  LOCAL spot_details IS spotDetails(lat,lng).
  LOCAL spot_v IS spot_details[0].
  LOCAL spot_up_v IS spot_details[1].

  // if very close to the North Pole, use a South-facing vector instead of North
  // (this will also result in the East vector pointing West)
  LOCAL north_mod IS 0.01.
  IF lat > (90-north_mod) { SET north_mod TO -north_mod. }
  LOCAL spot_north_v IS VXCL(spot_up_v, (LATLNG(lat+north_mod,lng):POSITION-spot_v):NORMALIZED).
  LOCAL spot_east_v IS VCRS(spot_up_v, spot_north_v).

  // spots 1, 2 and 3 form an equilateral triangle, 'radius' metres from the centre spot.
  // spot1 is radius metres North of the centre spot (unless .
  LOCAL spot1 IS BODY:GEOPOSITIONOF(spot_v + (radius * spot_north_v)).
  // spots 2 and 3 are 0.5 (sin(30) 'radius' metres South of the centre spot.
  // spots 2 and 3 are SQRT(3)/2 (cos(30) 'radius' metres East or West of the centre spot.
  LOCAL spot_south_mod_v IS (-0.5 * radius * spot_north_v).
  LOCAL spot_east_mod_v IS ((SQRT(3)/2) * radius * spot_east_v).

  LOCAL spot2 IS BODY:GEOPOSITIONOF(spot_v + spot_south_mod_v + spot_east_mod_v).
  LOCAL spot3 IS BODY:GEOPOSITIONOF(spot_v + spot_south_mod_v - spot_east_mod_v).

  LOCAL spot1_v IS spot1:ALTITUDEPOSITION(spot1:TERRAINHEIGHT).
  LOCAL spot2_v IS spot2:ALTITUDEPOSITION(spot2:TERRAINHEIGHT).
  LOCAL spot3_v IS spot3:ALTITUDEPOSITION(spot3:TERRAINHEIGHT).

  LOCAL slope_v IS VCRS(spot2_v - spot1_v, spot3_v - spot1_v):NORMALIZED.
  spot_details:ADD(slope_v).
  spot_details:ADD(VANG(slope_v, spot_up_v)).
  RETURN spot_details.
}

FUNCTION slopeAngle
{
  // radius is in metres
  PARAMETER lat, lng, radius IS 2.

  RETURN slopeDetails(lat, lng, radius)[4].
}

FUNCTION downhillVector
{
  // returns a horizontal vector that points "downhill"
  PARAMETER slope_details.

  LOCAL spot_up_v IS slope_details[1].
  LOCAL spot_slope_v IS slope_details[3].

  RETURN VXCL(spot_up_v, spot_slope_v):NORMALIZED.
}

FUNCTION findLowSlope
{
  // max_slope_ang is in degrees
  // radius is in metres
  PARAMETER max_slope_ang IS 5, lat IS SHIP:LATITUDE, lng IS SHIP:LONGITUDE, radius IS 2.

  pOut("findLowSlope() called with parameters:").
  pOut("  Max slope angle: " + max_slope_ang + " degrees.").
  pOut("  Latitude: " + lat).
  pOut("  Longitude: " + lng).
  pOut("  Radius: " + radius + "m.").

  CLEARVECDRAWS().

  LOCAL spots_to_keep IS 5.
  LOCAL max_stuck_count IS 2.

  LOCAL new_spot IS LATLNG(lat,lng).
  LOCAL visited_spots IS LIST(new_spot).
  LOCAL stuck_count IS 0.

  LOCAL slope_details IS slopeDetails(new_spot:LAT, new_spot:LNG, radius).
  LOCAL slope_ang IS slope_details[4].
  UNTIL slope_ang < max_slope_ang {

    // go 'radius' * ('angle' / 'max_ang')^2 metres down the slope (i.e. jump further
    // if the slope is further from being acceptable)

    LOCAL spot_v IS slope_details[0].
    LOCAL dh_v_unit IS downhillVector(slope_details).
    LOCAL dh_v IS radius * (slope_ang / max_slope_ang)^2 * dh_v_unit.
    SET new_spot TO BODY:GEOPOSITIONOF(spot_v+dh_v).

    // compare new_spot to recent spots we have visited (except the most recent)
    // if we keep finding ourselves near the same spot, jump away
    LOCAL spot_ok IS TRUE.
    LOCAL point_count IS 0.
    FOR visited_spot IN visited_spots {
      SET point_count TO point_count + 1.
      IF spot_ok AND point_count < visited_spots:LENGTH AND
         greatCircleDistance(BODY, visited_spot, new_spot) < radius {
        SET stuck_count TO stuck_count + 1.
        SET spot_ok TO FALSE.
      }
    }

    IF spot_ok {
      // remove oldest list members until we have space to add the latest point
      UNTIL visited_spots:LENGTH < spots_to_keep { visited_spots:REMOVE(0). }
    } ELSE {
      pOut("*** Think we are stuck. Jumping " + stuck_count + " kilometres away. ***").
      // jump 'stuck_count' kilometres in a random direction
      LOCAL spot_up_v IS slope_details[1].
      LOCAL random_rot IS ANGLEAXIS(RANDOM()*360, spot_up_v).
      SET dh_v TO stuck_count * 1000 * dh_v_unit.
      SET new_spot TO BODY:GEOPOSITIONOF(spot_v + (random_rot * dh_v)).

      // clear out list of visited spots
      visited_spots:CLEAR().
    }
    visited_spots:ADD(new_spot).

    LOCAL prev_lat IS new_spot:LAT.
    LOCAL prev_lng IS new_spot:LNG.
    LOCAL prev_spot_v IS slope_details[0].
    SET slope_details TO slopeDetails(new_spot:LAT, new_spot:LNG, radius).
    SET slope_ang TO slope_details[4].
    LOCAL diff_v IS slope_details[0]-prev_spot_v.
    pOut("New spot:").
    pOut("  Slope angle: " + ROUND(slope_ang,2) + " degrees.").
    pOut("  Latitude: " + new_spot:LAT).
    pOut("  Longitude: " + new_spot:LNG).
    LOCAL spot_dist IS diff_v:MAG.
    pOut("  Distance from previous spot: " + ROUND(spot_dist,1) + "m.").
    VECDRAW(prev_spot_v, diff_v, RGB(1,0,0), "Jump: "+ROUND(spot_dist,1)+"m", 1, TRUE).
  }

  pOut("findLowSlope() returning spot:").
  pOut("  Slope angle: " + ROUND(slope_ang,2) + " degrees.").
  pOut("  Latitude: " + new_spot:LAT).
  pOut("  Longitude: " + new_spot:LNG).
  LOCAL spot_dist IS greatCircleDistance(BODY, LATLNG(lat,lng), new_spot).
  pOut("  Distance from input spot: " + ROUND(spot_dist) + "m.").

  RETURN new_spot.
}

// test functions
FUNCTION drawSlope
{
  PARAMETER slope_details.

  LOCAL spot_v IS slope_details[0].
  LOCAL spot_slope_v IS slope_details[3].
  LOCAL spot_slope_ang IS ROUND(slope_details[4],1).

  VECDRAW(spot_v, 5 * spot_slope_v, RGB(1,1,0), "Slope: "+spot_slope_ang, 1, TRUE).
}

FUNCTION drawSlopesNearCraft
{
  // dist is in metres
  // steps must be odd - it will be incremented if necessary
  // steps^2 samples will be taken
  PARAMETER dist IS 10, steps IS 7.

  IF MOD(steps,2) = 0 { SET steps TO steps + 1. }
  LOCAL range_boundary IS (steps-1)/2.

  CLEARVECDRAWS().

  // counters/trackers
  LOCAL min_height IS 99999.
  LOCAL max_height IS -99999.
  LOCAL total_height IS 0.
  LOCAL min_slope IS 90.
  LOCAL max_slope IS 0.
  LOCAL total_slope IS 0.
  LOCAL count IS 0.

  // Cycle through a range of nearby latitudes and longitudes
  // On Kerbin, at the equator, the distance bewteen two points 1 degree apart is 10472m
  // Try to make the new values 'dist' m apart.
  // (they will be closer than this away from the equator, though)
  LOCAL adjust IS (BODY:RADIUS * CONSTANT:PI / 180) / dist.
  LOCAL lat IS SHIP:LATITUDE.
  LOCAL lng IS SHIP:LONGITUDE.
  FOR x IN RANGE (-range_boundary,range_boundary+1,1) {
    LOCAL new_lat IS lat + (x/adjust).
    FOR y IN RANGE (-range_boundary,range_boundary+1,1) {
      LOCAL new_lng IS lng + (y/adjust).

      SET count TO count + 1.
      LOCAL slope_details IS slopeDetails(new_lat, new_lng).
      LOCAL height IS slope_details[2].
      IF height < min_height { SET min_height TO height. }
      IF height > max_height { SET max_height TO height. }
      SET total_height TO total_height + height.
      LOCAL ang IS slope_details[4].
      IF ang < min_slope { SET min_slope TO ang. }
      IF ang > max_slope { SET max_slope TO ang. }
      SET total_slope TO total_slope + ang.
      drawSlope(slope_details).
    }
  }

  IF count > 0 {
    pOut("Minimum terrain height: " + ROUND(min_height) + "m.").
    pOut("Maximum terrain height: " + ROUND(max_height) + "m.").
    pOut("Average terrain height: " + ROUND(total_height / count) + "m.").
    pOut("Minimum slope angle: " + ROUND(min_slope, 1) + " degrees.").
    pOut("Maximum slope angle: " + ROUND(max_slope, 1) + " degrees.").
    pOut("Average slope angle: " + ROUND(total_slope / count, 1) + " degrees.").
  }
}