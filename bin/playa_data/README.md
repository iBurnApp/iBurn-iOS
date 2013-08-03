#Creating JSON feeds for iBurn
You may ask yourself, "How did I get here?"
##Source Data (./data)

####"Unofficial"" data

+ **art-2012.json** Descriptive data for art. The result of scraper.py for art installations
+ **camps-2012.json** Descriptive data for camps. The result of scraper.py for camps
+ **art-locations-2012** Art geodata from BMorg
+ **camp-locations-2012** Camp geodata from BMorg

####Official data from the [Playa Events API](http://playaevents.burningman.com/api/0.2/docs/)
+ **playaevents-art-2012.json** Descriptive data for Art installations
+ **playaevents-camps-2012.json** Descriptive data for camps
+ **playaevents-events-2012.json** Descriptive data for events

##The Python Modules


###merge_playaevents-camps.py##
**INPUT:** camp-locations-2012.json, playaevents-camps-2012.json, camps-2012.json (optional)

**OUTPUT:** ./results/camp_data_and_locations.json, ./results/unmatched_camps.json

This module merges camps from the scraper into the offical api feed, then adds location data (lat, lon, string of polar man coords) into this merged camp list from camp-locations-2012.

Camps for which no location was found are ALSO output to ./results/unmatched_camps.json for manual inspection.

###merge_playaevents-art.py##
**INPUT:** art-locations-2012.json, playaevents-art-2012.json, art-2012 (optional)

**OUTPUT:** ./results/art_data_and_locations.json, ./results/unmatched_art.json

This module merges art from the scraper into the offical api feed, then adds location data (lat, lon, string of polar man coords) into this merged event list from art-locations-2012.

Art for which no location was found are ALSO output to ./results/unmatched_art.json for manual inspection.

###merge_playaevents-events.py##
**INPUT:** camp-locations-2012.json, playaevents-events-2012.json,

**OUTPUT:** ./results/event_data_and_locations.json, ./results/unmatched_events.json

This module merges events from the scraper into the offical api feed, then adds location data (lat, lon, string of polar man coords) into this merged event list from camp-locations-2012.

Events for which no location was found are ALSO output to ./results/unmatched_camps.json for manual inspection.

###merge_camp_id_from_events.py##
**INPUT:** camp_data_and_locations.json, playaevents-events-2012.json

**OUTPUT:** ./results/camp_data_and_locations_ids.json, ./results/unmatched_camps_id.json

This module merges camp ids nested in the Playa Events API Event feed (some Events have a **hosted_by_camp** parameter, which reveals **name** and **id** of the host camp) into a JSON listing of camps.