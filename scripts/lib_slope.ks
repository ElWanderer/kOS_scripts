@LAZYGLOBAL OFF.

pOut("lib_slope.ks v1.0.0 20171101").

FOR f IN LIST(
  "lib_geo.ks"
) { RUNONCEPATH(loadScript(f)). }

FUNCTION spotDetails
{
  PARAMETER lat, lng.

  LOCAL spot IS LATLNG(lat, lng).
  LOCAL spot_height IS spot:TERRAINHEIGHT.
  LOCAL spot_v IS spot:ALTITUDEPOSITION(spot_height).
  LOCAL up_v IS (spot:ALTITUDEPOSITION(spot_height + 10000)-spot_v):NORMALIZED.
  RETURN LIST(spot_v, up_v, spot_height).
}

FUNCTION slopeDetails
{
  PARAMETER lat, lng, radius IS 2.

  LOCAL spot_details IS spotDetails(lat,lng).
  LOCAL spot_v IS spot_details[0].
  LOCAL spot_up_v IS spot_details[1].

  LOCAL north_mod IS 0.01.
  IF lat > (90-north_mod) { SET north_mod TO -north_mod. }
  LOCAL spot_north_v IS VXCL(spot_up_v, (LATLNG(lat+north_mod,lng):POSITION-spot_v):NORMALIZED).
  LOCAL spot_east_v IS VCRS(spot_up_v, spot_north_v).

  LOCAL spot1 IS BODY:GEOPOSITIONOF(spot_v + (radius * spot_north_v)).
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
  PARAMETER lat, lng, radius IS 2.
  RETURN slopeDetails(lat, lng, radius)[4].
}

FUNCTION downhillVector
{
  PARAMETER slope_details.
  LOCAL spot_up_v IS slope_details[1].
  LOCAL spot_slope_v IS slope_details[3].
  RETURN VXCL(spot_up_v, spot_slope_v):NORMALIZED.
}

FUNCTION findLowSlope
{
  PARAMETER max_slope_ang IS 5, lat IS SHIP:LATITUDE, lng IS SHIP:LONGITUDE, radius IS 2.

  LOCAL spots_to_keep IS 5.
  LOCAL max_stuck_count IS 2.

  LOCAL new_spot IS LATLNG(lat,lng).
  LOCAL visited_spots IS LIST(new_spot).
  LOCAL stuck_count IS 0.

  LOCAL slope_details IS slopeDetails(new_spot:LAT, new_spot:LNG, radius).
  LOCAL slope_ang IS slope_details[4].
  
  UNTIL slope_ang < max_slope_ang {
    LOCAL spot_v IS slope_details[0].
    LOCAL dh_v_unit IS downhillVector(slope_details).
    LOCAL dh_v IS radius * (slope_ang / max_slope_ang)^2 * dh_v_unit.
    SET new_spot TO BODY:GEOPOSITIONOF(spot_v+dh_v).

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
      UNTIL visited_spots:LENGTH < spots_to_keep { visited_spots:REMOVE(0). }
    } ELSE {
      LOCAL spot_up_v IS slope_details[1].
      LOCAL random_rot IS ANGLEAXIS(RANDOM()*360, spot_up_v).
      SET dh_v TO stuck_count * 1000 * dh_v_unit.
      SET new_spot TO BODY:GEOPOSITIONOF(spot_v + (random_rot * dh_v)).

      visited_spots:CLEAR().
    }
    visited_spots:ADD(new_spot).

    LOCAL prev_lat IS new_spot:LAT.
    LOCAL prev_lng IS new_spot:LNG.
    LOCAL prev_spot_v IS slope_details[0].
    SET slope_details TO slopeDetails(new_spot:LAT, new_spot:LNG, radius).
    SET slope_ang TO slope_details[4].
  }

  RETURN new_spot.
}
