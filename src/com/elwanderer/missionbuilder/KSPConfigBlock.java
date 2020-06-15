package com.elwanderer.missionbuilder;

import java.util.*;

public class KSPConfigBlock {

    private String name;
    private HashMap<String, String> contents;
    private List<KSPConfigBlock> subBlocks;
    private int braceCount;
    private boolean hasContent;

    public KSPConfigBlock(String n, int bc) {
        name = n;
        contents = new HashMap<String, String>();
        subBlocks = new ArrayList<KSPConfigBlock>();
        braceCount = bc;
        hasContent = false;
    }

    public boolean ReadBlock(Scanner s) {
        String nextBlockName = "";
        boolean ok = true;
        boolean closed = false;

        while (ok && !closed && s.hasNext()) {
            // each line should contain one of the following options:
            // 1. a key = value pair
            //  - add to contents
            // 2. an opening brace {
            //  - we might expect one of these, depending on how we created the block
            //  - once we have met more than expected, create a sub-block from what follows
            // 3. a closing brace }
            //  - stop reading and return
            // 4. the name of the next block
            //  - store it in nextBlockName and expect to hit an opening brace next
            String line = s.nextLine().trim();
            if (line.contains("=")) {
                String[] map = line.split("=", 0);
                if (map.length == 1) {
                    contents.put(map[0].trim(), "");
                } else if (map.length == 2) {
                    contents.put(map[0].trim(), map[1].trim());
                } else {
                    System.out.println("Unexpected number of tokens in key/value pair: " + line);
                }
            } else if (line.equals("{")) {
                braceCount++;
                if (braceCount > 1) {
                    KSPConfigBlock sub = new KSPConfigBlock(nextBlockName, 1); // braceCount is 1 as we've just popped
                                                                               // the brace here
                    ok = sub.ReadBlock(s);
                    if (ok) {
                        subBlocks.add(sub);
                        braceCount--;
                    }
                }
            } else if (line.equals("}")) {
                braceCount--;
                if (braceCount != 0) {
                    System.out.println("Unexpected closing brace count: " + braceCount);
                    ok = false;
                }
                closed = true;
            } else {
                nextBlockName = line;
            }
        }
        hasContent = (!contents.entrySet().isEmpty() || subBlocks != null);
        return (ok && closed);
    }

    public HashMap<String, String> getContents() {
        return contents;
    }

    public List<KSPConfigBlock> getSubBlocks() {
        return subBlocks;
    }

    // if not found, returns ""
    public String getField(String n) {
        String returnVal = "";
        if (contents.containsKey(n)) {
            returnVal = contents.get(n);
        }
        return returnVal;
    }

    // if not found, returns an empty config block
    public KSPConfigBlock getNamedSubBlock(String n) {
        Iterator<KSPConfigBlock> it = subBlocks.iterator();
        while (it.hasNext()) {
            KSPConfigBlock paramBlock = it.next();
            String name = paramBlock.getField("name");
            if (name.equals(n)) {
                return paramBlock;
            }
        }
        return new KSPConfigBlock(n, 0);
    }

    // if not found, returns ""
    public String getStringField(String path) {
        String returnVal = "";
        KSPConfigBlock block = this;
        String[] pathElements = path.split("\\\\", 0);

        for (int i = 0; i < pathElements.length; i++) {
            String n = pathElements[i];
            if (i == pathElements.length - 1) {
                returnVal = block.getField(n);
            } else {
                block = block.getNamedSubBlock(n);
            }
        }

        return returnVal;
    }

    // if not found, returns 0
    public int getIntField(String path) {
        try {
            return Integer.parseInt(getStringField(path));
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    // if not found, returns 0.0
    public double getDoubleField(String path) {
        try {
            return Double.parseDouble(getStringField(path));
        } catch (NumberFormatException e) {
            return 0.0;
        }
    }

    public String toString() {
        String returnVal = "";
        if (hasContent) {
            returnVal += "Start of [" + name + "] block\n";

            for (Map.Entry<String, String> entry : contents.entrySet()) {
                String key = entry.getKey();
                String value = entry.getValue();

                returnVal += key + "=" + value + "\n";
            }

            // contents.forEach((k,v) -> returnVal += k + "=" + v + "\n"); // wants
            // returnVal to be final :/

            Iterator<KSPConfigBlock> it = subBlocks.iterator();
            while (it.hasNext()) {
                returnVal += it.next().toString();
            }
            returnVal += "End of [" + name + "] block\n";
        }
        return returnVal;
    }

}
