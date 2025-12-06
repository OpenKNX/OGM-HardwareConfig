# Parsing Device-Definitions
# (C) 2025 Cornelius Köpp; For Usage in OpenKNX-Project only

import os
import re
import json

def find_header_files(directory):
    """
    Diese Funktion sucht rekursiv im Verzeichnisbaum nach Header-Dateien (.h).
    """
    header_files = []
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(".h"):
                headerpath = os.path.join(root, file)
                header_files.append(headerpath)
                print(f"  > found '{headerpath}'")
    return header_files

def extract_devices_from_header(file_path):
    """
    Diese Funktion durchsucht eine Header-Datei nach den DEVICE_ Definitionen und extrahiert die DeviceID und DeviceName.
    Gibt zusätzlich die Zeilennummern der Matches aus.
    """
    devices = []
    # Regex for DEVICE_ definitions AND special cases: PREFIX_
    device_pattern = re.compile(
        r"\W*?#define PREFIX_ID \"(?P<prefix_id>[^\"]+)\"\W*(//.*)?\n"
        r"\W*?#define PREFIX_NAME \"(?P<prefix_name>[^\"]+)\""
        r"|"
        r"\W*(?P<line1>//\W*(?P<line1c>.*))?\n"
        r"\W*(?P<line2>//\W*(?P<line2c>.*))?\n"
        r"\W*(?P<condition>#if.*)\W*\n"
        r"\W*?#define DEVICE_ID (?P<_prefix_id>PREFIX_ID ?)?(\"(?P<device_id>[^\"]*)\")?\W*(//.*)?\n"
        r"\W*?#define DEVICE_NAME (?P<_prefix_name>PREFIX_NAME ?)?(\"(?P<device_name>[^\"]*)\")?"
    )
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            content = file.read()
            lines = content.splitlines()
            matches = device_pattern.finditer(content)
            prefix = {}
            prefix_range = {}
            devices_found = 0
            for match in matches:
                # calc line-range
                match_start = match.start()
                line_number = content[:match_start].count('\n') + 1
                line_number_end = line_number + match.group(0).count('\n')
                line_range = f"{line_number}-{line_number_end}"

                if match.group("prefix_id"):
                    prefix_id = match.group("prefix_id")
                    prefix_name = match.group("prefix_name")
                    print(f"  i found prefix '{prefix_id}' and '{prefix_name}' at lines {line_range}")
                    if devices_found > 0:
                        print(f"  -> use prefix alone")
                        prefix = {}
                        prefix_range = {}
                    else:
                        print(f"  -> add prefix to list")

                    prefix[prefix_id] = prefix_name
                    prefix_range[prefix_id] = line_range
                    devices_found = 0
                else:
                    dev_condition = match.group("condition")
                    dev_device_id = match.group("device_id")
                    dev_device_name = match.group("device_name")
                    dev_teaser = [line for line in [match.group("line1c"), match.group("line2c")] if line]
                    if not match.group("_prefix_id") or not match.group("_prefix_name"):
                        if len(prefix):
                            prefix = {}
                            prefix_range = {}
                            devices_found = 0
                            print(f"  -> clear prefix list")
                    for prefix_id, prefix_name in (prefix if prefix else {"": ""}).items():
                        devices.append({
                            "Condition": dev_condition,
                            "DeviceID": prefix_id + (dev_device_id if dev_device_id else ""),
                            "DeviceName": prefix_name + (dev_device_name if dev_device_name else ""),
                            "SourceFile": f"{file_path.replace("\\", "/")}:{",".join(([prefix_range[prefix_id]] if prefix_id != "" else [])  + [line_range])}",
                            "Teaser": dev_teaser,
                        })
                        devices_found += 1
                        print(f'  > found {devices[-1]["DeviceID"]} ("{devices[-1]["DeviceName"]}") at line {line_range}')
    except (IOError, UnicodeDecodeError) as e:
        print(f"Fehler beim Lesen der Datei {file_path}: {e}")

    return devices

def main():
    # list all header files with ending '.h'
    print(f"Find Header-Files ...")
    header_files = find_header_files("./include/")
    print(f"[DONE] {len(header_files)} Header-Files found\n")

    # collect device definitions from all header files
    all_devices_list = []
    for header_file in header_files:
        print(f"Parse Header-File '{header_file}' ...")
        all_devices_list.extend(extract_devices_from_header(header_file))
    print(f"[DONE] {len(all_devices_list)} Device-Definitions found\n")

    # map the devices by DeviceID
    all_devices_map = {dev["DeviceID"]: dev for dev in all_devices_list}
    if len(all_devices_map) != len(all_devices_list):
        print(f"[ERROR]: {len(all_devices_list) - len(all_devices_map)} duplicates found in DeviceID:")
        duplicates = {}
        for dev in all_devices_list:
            if dev["DeviceID"] in duplicates:
                duplicates[dev["DeviceID"]].append(dev)
            else:
                duplicates[dev["DeviceID"]] = [dev]
        for dev_id, dev_list in duplicates.items():
            if len(dev_list) > 1:
                print(f"  > {dev_id}:")
                for dev in dev_list:
                    print(f"    - {dev['DeviceName']} ({dev['SourceFile']})")



        # exit(1)
    print(f"[DONE] Mapped Definitions by DeviceID")

    # save the structured device data
    output_file = "devices.json"
    with open(output_file, 'w', encoding='utf-8') as json_file:
        json.dump(all_devices_map, json_file, indent=4, ensure_ascii=False)

    print("[COMPLETED]")

if __name__ == "__main__":
    main()