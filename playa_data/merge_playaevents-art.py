import Levenshtein
import json
from string_util import cleanString
'''
    This script merges art locations from art-locations-2012.json
    into art entries from playaevents-art-2012.json
    (The Playa Events API Art feed)
'''
# Threshold under which to discard partial string matches
MATCH_THRESHOLD = .7

location_file = open('./data/art-locations-2012.json')
playa_art_file = open('./data/playaevents-art-2012.json')
scraper_art_file = open('./data/art-2012.json')
# Comment out the above line to disregard scraper data

location_json = json.loads(location_file.read())
playa_json = json.loads(playa_art_file.read())
if scraper_art_file:
    scraper_json = json.loads(scraper_art_file.read())

# Some entries in art_data are null, remove them before writing final json
null_art_indexes = []

# art without a match, for manual inspection
unmatched_art = []

# First, merge camps-2012.json data into playaevents-camps-2012.json
if scraper_art_file:
    for scraper_art in scraper_json:
        max_match = 0
        max_match_playa_art_index = -1
        if scraper_art != None:
            for index, playa_art in enumerate(playa_json):
                if scraper_art != None:
                    match = Levenshtein.ratio(cleanString(playa_art['name']), cleanString(scraper_art['title']))
                    if match > max_match:
                        max_match = match
                        max_match_playa_art_index = index
            #print "Best match for " + camp['name'] + " : " + max_match_location['name'] + " (confidence: " + str(max_match) + ")"
            if max_match > MATCH_THRESHOLD:
                pass
                # Match found. Merge scraper data into playa data
                # For now, at least, it doesn't look like there's
                # Any ADDITIONAL data of interest in the scraper entries
            else:
                # Scoop the useful fields out of the scraper entry
                # formatting them like the playaevents list
                new_entry = {}
                new_entry['name'] = scraper_art['title']
                new_entry['description'] = scraper_art['description']
                new_entry['artst'] = scraper_art['artists']
                # Add scraper data entry into playa data
                playa_json.append(new_entry)
                print "merged scraper entry: " + str(scraper_art)

# match name fields between entries in two files
for index, art in enumerate(playa_json):
    max_match = 0
    max_match_location = ''
    if art != None and 'name' in art:
        for location in location_json:
                match = Levenshtein.ratio(cleanString(location['name']), cleanString(art['name']))
                if match > max_match:
                    max_match = match
                    max_match_location = location
        #print "Best match for " + art['name'] + " : " + max_match_location['name'] + " (confidence: " + str(max_match) + ")"
        if max_match > MATCH_THRESHOLD:
            # Match found
            if 'latitude' in max_match_location and max_match_location['latitude'] != "":
                art['latitude'] = max_match_location['latitude']
                art['longitude'] = max_match_location['longitude']
            art['matched_name'] = max_match_location['name']
            art['distance'] = max_match_location['distance']
            art['hour'] = max_match_location['hour']
            art['minute'] = max_match_location['minute']
        else:
            unmatched_art.append(art)
    elif not 'title' in art:
        null_art_indexes.append(index)

# To remove null entries from list, we must move in reverse
# to preserve list order as we remove
null_art_indexes.reverse()
for index in null_art_indexes:
    playa_json.pop(index)

unmatched_art_file = open('./results/unmatched_art.json', 'w')
unmatched_art_file.write(json.dumps(unmatched_art, sort_keys=True, indent=4))

result_file = open('./results/art_data_and_locations.json', 'w')
result_file.write(json.dumps(playa_json, sort_keys=True, indent=4))

if len(unmatched_art) > 0:
    print "Location not determined for " + str(len(unmatched_art)) + " art pieces"
