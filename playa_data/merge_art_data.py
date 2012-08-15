import Levenshtein
import json
from string_util import cleanString

# Threshold under which to discard partial string matches
MATCH_THRESHOLD = .6

location_file = open('art_locations.json')
art_file = open('art_data.json')

location_json = json.loads(location_file.read())
art_json = json.loads(art_file.read())

# Some entries in art_data are null, remove them before writing final json
null_art_indexes = []

# art without a match, for manual inspection
unmatched_art = []

# match name fields between entries in two files
for index, art in enumerate(art_json):
    max_match = 0
    max_match_location = ''
    if art != None and 'title' in art:
        for location in location_json:
                match = Levenshtein.ratio(cleanString(location['title']), cleanString(art['title']))
                if match > max_match:
                    max_match = match
                    max_match_location = location
        #print "Best match for " + art['name'] + " : " + max_match_location['name'] + " (confidence: " + str(max_match) + ")"
        if max_match > MATCH_THRESHOLD:
            # Match found
            art['latitude'] = max_match_location['lat']
            art['longitude'] = max_match_location['lon']
            art['matched_name'] = max_match_location['title']
            art['tstreet'] = max_match_location['tstreet']
            art['distance'] = max_match_location['distance']
        else:
            unmatched_art.append(art)
    elif not 'title' in art:
        null_art_indexes.append(index)

# To remove null entries from list, we must move in reverse
# to preserve list order as we remove
null_art_indexes.reverse()
for index in null_art_indexes:
    art_json.pop(index)

unmatched_art_file = open('./results/unmatched_art.json', 'w')
unmatched_art_file.write(json.dumps(unmatched_art, sort_keys=True, indent=4))

result_file = open('./results/art_data_and_locations.json', 'w')
result_file.write(json.dumps(art_json, sort_keys=True, indent=4))

if len(unmatched_art) > 0:
    print "Matches not found for " + str(len(unmatched_art)) + " art pieces"
