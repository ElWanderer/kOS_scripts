package com.elwanderer.missionbuilder;

public class Utils {

    static private final String WIN_FILE_SEPARATOR = System.getProperty("file.separator");
    static private final String WIN_PROG_FILES_X86_PATH = System.getenv("ProgramFiles(X86)");

    static private final double SECONDS_IN_MINUTE = 60.0;
    static private final double SECONDS_IN_HOUR = 60.0 * SECONDS_IN_MINUTE;
    static private final double SECONDS_IN_DAY = 6.0 * SECONDS_IN_HOUR; // Kerbin not Earth!
    static private final double SECONDS_IN_YEAR = 426.0 * SECONDS_IN_DAY; // Kerbin not Earth!

    public static double roundToDP(double num, int numDP) {
        if (numDP > 0) {
            double exp = Math.pow(10.0, numDP);
            return Math.round(num * exp) / exp;

        } else {
            return Math.round(num);
        }
    }

    public static String padString(String input, String padding, int requiredLength) {
        String returnVal = input;

        while (returnVal.length() < requiredLength) {
            returnVal = padding + returnVal;
        }

        return returnVal;
    }

    public static double getSecondsInYear() {
        return SECONDS_IN_YEAR;
    }

    public static String getTimeString(double universalTime) {

        int years = (int) Math.floor(universalTime / SECONDS_IN_YEAR);
        double remain = universalTime - (years * SECONDS_IN_YEAR);

        int days = (int) Math.floor(remain / SECONDS_IN_DAY);
        remain -= (days * SECONDS_IN_DAY);

        int hours = (int) Math.floor(remain / SECONDS_IN_HOUR);
        remain -= (hours * SECONDS_IN_HOUR);

        int minutes = (int) Math.floor(remain / SECONDS_IN_MINUTE);
        remain -= (minutes * SECONDS_IN_MINUTE);

        int seconds = (int) Math.floor(remain);

        String hoursString = padString("" + hours, "0", 2);
        String minutesString = padString("" + minutes, "0", 2);
        String secondsString = padString("" + seconds, "0", 2);

        return "Y" + (years + 1) + " D" + (days + 1) + " " + hoursString + ":" + minutesString + ":" + secondsString;
    }
    
    public static String getDurationString(double duration) {
        int years = (int) Math.floor(duration / SECONDS_IN_YEAR);
        double remain = duration - (years * SECONDS_IN_YEAR);

        int days = (int) Math.floor(remain / SECONDS_IN_DAY);
        remain -= (days * SECONDS_IN_DAY);

        int hours = (int) Math.floor(remain / SECONDS_IN_HOUR);
        remain -= (hours * SECONDS_IN_HOUR);

        int minutes = (int) Math.floor(remain / SECONDS_IN_MINUTE);
        remain -= (minutes * SECONDS_IN_MINUTE);

        int seconds = (int) Math.floor(remain);
        
        String returnVal = "";
        if (years > 0) { returnVal += years + "y "; }
        if (days > 0) { returnVal += days + "d "; }
        if (hours > 0) { returnVal += hours + "h"; }
        if (minutes > 0 || hours > 0) { returnVal += minutes + "m"; }
        returnVal += seconds + "s";
        
        return returnVal;
    }

    public static String getDirectoryUnderProgramFilesX86(String[] paths) {

        String returnPath = WIN_PROG_FILES_X86_PATH;

        for (String p : paths) {
            returnPath += WIN_FILE_SEPARATOR + p;
        }

        return returnPath;
    }
    
    // Like Math.cos() but takes an angle in degrees instead of radians
    public static double cos(double ang) {
        return Math.cos(Math.toRadians(ang));
    }
    
    // Like Math.sin() but takes an angle in degrees instead of radians
    public static double sin(double ang) {
        return Math.sin(Math.toRadians(ang));
    }
}
