import Levenshtein
import json
from string_util import cleanString

# Threshold under which to discard partial string matches
MATCH_THRESHOLD = .6

location_file = open('camp_locations.json')
meta_file = open('camp_data.json')

location_json = json.loads(location_file.read())
meta_json = json.loads(meta_file.read())

# Some entries in camp_data are null, remove them before writing final json
null_camp_indexes = []

# camps without a match, for manual inspection
unmatched_camps = []

# match name fields between entries in two files
for index, camp in enumerate(meta_json):
    max_match = 0
    max_match_location = ''
    if camp != None:
        for location in location_json:
                match = Levenshtein.ratio(cleanString(location['name']), cleanString(camp['name']))
                if match > max_match:
                    max_match = match
                    max_match_location = location
        #print "Best match for " + camp['name'] + " : " + max_match_location['name'] + " (confidence: " + str(max_match) + ")"
        if max_match > MATCH_THRESHOLD:
            # Match found
            camp['latitude'] = max_match_location['latitude']
            camp['longitude'] = max_match_location['longitude']
            camp['location'] = max_match_location['location']
            camp['matched_name'] = max_match_location['name']
        else:
            unmatched_camps.append(camp)
    else:
        null_camp_indexes.append(index)

# To remove null entries from list, we must move in reverse
# to preserve list order as we remove
null_camp_indexes.reverse()
for index in null_camp_indexes:
    meta_json.pop(index)

unmatched_camps_file = open('./results/unmatched_camps.json', 'w')
unmatched_camps_file.write(json.dumps(unmatched_camps, sort_keys=True, indent=4))

result_file = open('./results/camp_data_and_locations.json', 'w')
result_file.write(json.dumps(meta_json, sort_keys=True, indent=4))

if len(unmatched_camps) > 0:
    print "Matches not found for " + str(len(unmatched_camps)) + " camps"
