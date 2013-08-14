import Levenshtein
import json
from string_util import cleanString, convert_html_entities
'''
    This script merges event locations from camp-locations-2013.json
    into events from playaevents-events-2013.json
    (The Playa Events API Events feed)
'''
# Threshold under which to discard partial string matches
MATCH_THRESHOLD = .7

location_file = open('./data/camp-locations-2013.json')
events_file = open('./data/playaevents-events-2013.json')

location_json = json.loads(location_file.read())
events_json = json.loads(events_file.read())

# Some entries in event_data are null, remove them before writing final json
null_event_indexes = []

# events without a match, for manual inspection
unmatched_events = []
matched_events = []

# match name fields between entries in two files
for index, event in enumerate(events_json):
    max_match = 0
    max_match_location = ''
    if event != None and 'hosted_by_camp' in event:
        for location in location_json:
                match = Levenshtein.ratio(cleanString(location['name']), cleanString(event['hosted_by_camp']['name']))
                if match > max_match:
                    max_match = match
                    max_match_location = location
        #print "Best match for " + event['name'] + " : " + max_match_location['name'] + " (confidence: " + str(max_match) + ")"
        if max_match > MATCH_THRESHOLD:
            # Match found
            if 'latitude' in max_match_location and max_match_location['latitude'] != "":
                event['latitude'] = max_match_location['latitude']
                event['longitude'] = max_match_location['longitude']
            #event['location'] = max_match_location['location']
            event['matched_name'] = max_match_location['name']
            matched_events.append(event)
        else:
            unmatched_events.append(event)
    elif not 'hosted_by_camp' in event:
        null_event_indexes.append(index)

# To remove null entries from list, we must move in reverse
# to preserve list order as we remove
null_event_indexes.reverse()
for index in null_event_indexes:
    events_json.pop(index)

unmatched_events_file = open('./results/unmatched_events.json', 'wb')
unmatched_events_file.write(convert_html_entities(json.dumps(unmatched_events, sort_keys=True, indent=4)))

result_file = open('./results/event_data_and_locations.json', 'wb')
result_file.write(convert_html_entities(json.dumps(events_json, sort_keys=True, indent=4)))

if len(unmatched_events) > 0:
    print "Matches not found for " + str(len(unmatched_events)) + " events"

print "Matched events: "+ str(len(matched_events))
