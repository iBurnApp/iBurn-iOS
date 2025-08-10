# Events with Negative Duration in 2025 Data

Total events with negative duration: **207**

## Summary

These events have end times that occur before their start times, resulting in negative durations.
This appears to be a data issue where the end date is incorrectly set to an earlier day than the start date.

## Additional Issue Fixed: Stale Event Data
During investigation, discovered that old events from previous imports were not being removed properly.
The cleanup code was checking the wrong collection for recurring events, leaving hundreds of stale events in the database.

## Solution Implemented

### Problem
- The PlayaEvents API returns events with invalid date ranges (end before start)
- BRCRecurringEventObject was creating events with these invalid dates
- This caused negative duration display in the UI (e.g., "(-22h)")

### Fix Applied
1. **BRCRecurringEventObject.m**: Three-step validation process:
   - First: Swap start/end dates when end is before start (fixes data entry errors)
   - Then: Validate swapped events against festival dates (Aug 24 - Sep 1, 2025)
   - Finally: Mark events over 12 hours as all-day (fixes API data quality issue)
   - Only add events that pass validation
2. **BRCEventObject.m**: Added defensive check to return 0 duration instead of negative
3. **BRCEventObject_Private.h**: Made isAllDay property writable for import corrections
4. **BRCDataImporter.m**: Fixed critical bug where event cleanup was checking wrong collection
   - Events are stored in BRCEventObject collection but cleanup was only checking BRCRecurringEventObject
   - Now properly removes outdated events from both collections
5. All changes include logging to track data quality issues

### Code Changes
- Swap dates for events where end is before start (attempts to fix the data)
- After swapping, validate all events against festival dates
- For multi-day events, validate each split day separately
- Mark events over 12 hours as all-day (corrects API data quality issue)
- Skip any events that fall outside the official Burning Man dates
- Return 0 duration for any remaining negative durations as a safety net
- This approach fixes recoverable data while filtering out truly invalid events

### Examples:
- Event with Aug 28 end, Aug 26 start → Swapped to Aug 26-28 → Valid, added
- Event with June 26 end, Aug 26 start → Swapped to June 26-Aug 26 → Invalid (June outside festival), skipped
- Multi-day event spanning Aug 23-25 → Only Aug 24-25 portions added (Aug 23 filtered out)

## Checking Script

Use this Python script to check for negative duration events in the data:

```python
import json
import datetime

def check_negative_durations(json_path):
    with open(json_path, 'r') as f:
        events = json.load(f)

    negative_duration_events = []
    for event in events:
        if 'occurrence_set' in event:
            for occurrence in event['occurrence_set']:
                start = datetime.datetime.fromisoformat(occurrence['start_time'])
                end = datetime.datetime.fromisoformat(occurrence['end_time'])
                duration = (end - start).total_seconds() / 3600
                if duration < 0:
                    negative_duration_events.append({
                        'title': event.get('title', 'Unknown'),
                        'uid': event.get('uid', 'Unknown'),
                        'event_id': event.get('event_id', 'Unknown'),
                        'start': occurrence['start_time'],
                        'end': occurrence['end_time'],
                        'duration_hours': duration,
                        'hosted_by_camp': event.get('hosted_by_camp', ''),
                        'description': event.get('description', '')[:100]
                    })

    # Sort by duration (most negative first)
    negative_duration_events.sort(key=lambda x: x['duration_hours'])
    
    print(f'Found {len(negative_duration_events)} events with negative duration\n')
    
    if negative_duration_events:
        print('Top 10 most extreme cases:')
        for i, e in enumerate(negative_duration_events[:10], 1):
            print(f"{i}. {e['title']}: {e['duration_hours']:.1f}h")
            print(f"   Start: {e['start']}")
            print(f"   End: {e['end']}")
            print()
    else:
        print('✅ No events with negative duration found!')
    
    return negative_duration_events

# Run with:
# python3 check_events.py Submodules/iBurn-Data/data/2025/APIData/APIData.bundle/event.json
```

## Complete List of Affected Events

| Title | Duration | Start Time | End Time | Event ID |
|-------|----------|------------|----------|----------|
| UKRAINIAN FASHION: FLOWER CROWN MAKING | -1462.5h | 2025-08-26T15:00:00-07:00 | 2025-06-26T16:30:00-07:00 | 52390 |
| Last dance party! | -191.8h | 2025-09-01T17:30:00-07:00 | 2025-08-24T17:45:00-07:00 | 50933 |
| Phantasmagoria bar | -181.0h | 2025-09-01T13:00:00-07:00 | 2025-08-25T00:00:00-07:00 | 53009 |
| Temple Narcotics Anonymous Unity Meeting | -167.0h | 2025-08-31T09:00:00-07:00 | 2025-08-24T10:00:00-07:00 | 51429 |
| B2B | -165.0h | 2025-08-31T06:00:00-07:00 | 2025-08-24T09:00:00-07:00 | 53632 |
| Deja Boom | -164.0h | 2025-08-30T22:00:00-07:00 | 2025-08-24T02:00:00-07:00 | 52035 |
| Sake Bomb Sunday | -163.0h | 2025-08-31T12:15:00-07:00 | 2025-08-24T17:15:00-07:00 | 52848 |
| Come dance the night away with us | -161.0h | 2025-08-30T22:00:00-07:00 | 2025-08-24T05:00:00-07:00 | 54241 |
| Sluttly MOOP Walk | -142.0h | 2025-08-30T14:00:00-07:00 | 2025-08-24T16:00:00-07:00 | 50978 |
| Slutty Sledding Saturday! | -142.0h | 2025-08-30T18:00:00-07:00 | 2025-08-24T20:00:00-07:00 | 52509 |
| Bloody Mary Party | -142.0h | 2025-08-30T10:00:00-07:00 | 2025-08-24T12:00:00-07:00 | 52479 |
| Body Paint Ritual: Express & Transform | -142.0h | 2025-08-30T18:00:00-07:00 | 2025-08-24T20:00:00-07:00 | 53209 |
| Oval Ascension: Femme Masturbation Party | -142.0h | 2025-08-30T13:00:00-07:00 | 2025-08-24T15:00:00-07:00 | 53547 |
| Hungover Yoga | -119.0h | 2025-08-29T11:00:00-07:00 | 2025-08-24T12:00:00-07:00 | 51868 |
| Portal to Intimacy | -119.0h | 2025-08-29T12:00:00-07:00 | 2025-08-24T13:00:00-07:00 | 53305 |
| Ask an OB/GYN with a baby anything! | -119.0h | 2025-08-29T11:00:00-07:00 | 2025-08-24T12:00:00-07:00 | 53557 |
| Date Night Foreplay | -119.0h | 2025-08-29T20:00:00-07:00 | 2025-08-24T21:00:00-07:00 | 53899 |
| Cathartic Writing Workshop | -118.5h | 2025-08-29T16:00:00-07:00 | 2025-08-24T17:30:00-07:00 | 52223 |
| Shabbat pot luck for all | -118.5h | 2025-08-29T19:00:00-07:00 | 2025-08-24T20:30:00-07:00 | 52230 |
| WristWords Workshop | -118.5h | 2025-08-29T13:00:00-07:00 | 2025-08-24T14:30:00-07:00 | 54639 |
| In Our Burning Man Era | -118.0h | 2025-08-29T11:00:00-07:00 | 2025-08-24T13:00:00-07:00 | 51970 |
| Future Filmmakers Red Carpet Premiere | -118.0h | 2025-08-29T15:00:00-07:00 | 2025-08-24T17:00:00-07:00 | 54005 |
| Shock the Conscience Storytelling | -118.0h | 2025-08-29T18:00:00-07:00 | 2025-08-24T20:00:00-07:00 | 54476 |
| Black Rock City Shabbat Service x Dinner! | -117.0h | 2025-08-29T18:30:00-07:00 | 2025-08-24T21:30:00-07:00 | 53600 |
| Metal Mania Party | -115.0h | 2025-08-29T09:00:00-07:00 | 2025-08-24T14:00:00-07:00 | 53665 |
| Thursday night Throwdown | -110.5h | 2025-08-28T20:30:00-07:00 | 2025-08-24T06:00:00-07:00 | 54115 |
| Heart-Centred Poetry Circle | -107.0h | 2025-08-28T11:00:00-07:00 | 2025-08-24T00:00:00-07:00 | 52960 |
| Shuffle Dancing 101 with Gaby | -95.0h | 2025-08-28T11:00:00-07:00 | 2025-08-24T12:00:00-07:00 | 52325 |
| PlayaPops Symphony Orchestra | -95.0h | 2025-08-28T10:30:00-07:00 | 2025-08-24T11:30:00-07:00 | 53259 |
| Intimate Sculptures | -94.5h | 2025-08-28T15:30:00-07:00 | 2025-08-24T17:00:00-07:00 | 51480 |
| Cum and Make Sum Noise | -94.0h | 2025-08-28T14:30:00-07:00 | 2025-08-24T16:30:00-07:00 | 51199 |
| Inner Child Favorites Sing-a-Long | -94.0h | 2025-08-28T14:00:00-07:00 | 2025-08-24T16:00:00-07:00 | 51652 |
| Thicccck Thursday | -94.0h | 2025-08-28T13:00:00-07:00 | 2025-08-24T15:00:00-07:00 | 53615 |
| Bacon, Booze and Beats! | -94.0h | 2025-08-28T14:00:00-07:00 | 2025-08-24T16:00:00-07:00 | 53672 |
| Radical Inclusion for Artificial Minds | -94.0h | 2025-08-28T14:00:00-07:00 | 2025-08-24T16:00:00-07:00 | 53489 |
| Grilled Cheese and Baconstravaganza! | -94.0h | 2025-08-28T11:00:00-07:00 | 2025-08-24T13:00:00-07:00 | 53060 |
| Morning Tea with the Beatles | -94.0h | 2025-08-28T10:00:00-07:00 | 2025-08-24T12:00:00-07:00 | 54200 |
| Blowout Speed Dating! | -94.0h | 2025-08-28T14:00:00-07:00 | 2025-08-24T16:00:00-07:00 | 54456 |
| Hear Ye, Hear Ye! Log On to Ye Ole Internet Party! | -94.0h | 2025-08-28T12:00:00-07:00 | 2025-08-24T14:00:00-07:00 | 54651 |
| Body Painting | -93.5h | 2025-08-28T14:00:00-07:00 | 2025-08-24T16:30:00-07:00 | 53574 |
| Keys and Cocktails, A Big Easy Sunset Soiree | -93.5h | 2025-08-28T19:00:00-07:00 | 2025-08-24T21:30:00-07:00 | 53680 |
| Flirty Fun Connection Dating | -93.0h | 2025-08-28T10:00:00-07:00 | 2025-08-24T13:00:00-07:00 | 53923 |
| Banana Karaoke | -93.0h | 2025-08-28T14:00:00-07:00 | 2025-08-24T17:00:00-07:00 | 54546 |
| Dapper Disco | -92.0h | 2025-08-28T19:00:00-07:00 | 2025-08-24T23:00:00-07:00 | 51329 |
| Disco Never Dies | -91.0h | 2025-08-28T09:00:00-07:00 | 2025-08-24T14:00:00-07:00 | 53663 |
| SOIREE BLANCHE - WHITE PARTY | -81.0h | 2025-08-27T21:00:00-07:00 | 2025-08-24T12:00:00-07:00 | 53760 |
| Living in the Anthropocene: Why all this Plastic? | -71.0h | 2025-08-27T14:00:00-07:00 | 2025-08-24T15:00:00-07:00 | 51237 |
| Woman menstrual phases and the moon powers | -71.0h | 2025-08-27T10:00:00-07:00 | 2025-08-24T11:00:00-07:00 | 51824 |
| Healing Herbal Facials | -71.0h | 2025-08-27T14:00:00-07:00 | 2025-08-24T15:00:00-07:00 | 52068 |
| Gentle Awareness Meditation with David | -71.0h | 2025-08-27T11:00:00-07:00 | 2025-08-24T12:00:00-07:00 | 52326 |
| Ally your STI | -71.0h | 2025-08-27T14:00:00-07:00 | 2025-08-24T15:00:00-07:00 | 52331 |
| Chicken Ranch Cock Toss | -71.0h | 2025-08-27T12:00:00-07:00 | 2025-08-24T13:00:00-07:00 | 52637 |
| The Soil is ALIVE! A talk about dirt | -71.0h | 2025-08-27T15:30:00-07:00 | 2025-08-24T16:30:00-07:00 | 53436 |
| Kung Fu Cupcake | -71.0h | 2025-08-28T09:00:00-07:00 | 2025-08-25T10:00:00-07:00 | 53898 |
| Welcome to the Funhouse | -71.0h | 2025-08-27T21:00:00-07:00 | 2025-08-24T22:00:00-07:00 | 53047 |
| Mehndi and Munchies | -71.0h | 2025-08-27T16:30:00-07:00 | 2025-08-24T17:30:00-07:00 | 54029 |
| Cloud 10- Yoga and Sound | -71.0h | 2025-08-27T09:30:00-07:00 | 2025-08-24T10:30:00-07:00 | 54290 |
| Cloud 10- Yoga and Sound | -71.0h | 2025-08-27T09:30:00-07:00 | 2025-08-24T10:30:00-07:00 | 54289 |
| Drunken Disney Sing-A-Long! (10th Annual!) | -70.8h | 2025-08-27T12:00:00-07:00 | 2025-08-24T13:15:00-07:00 | 51443 |
| Ceremony Reconciling Fire and Water | -70.5h | 2025-08-27T05:30:00-07:00 | 2025-08-24T07:00:00-07:00 | 51055 |
| Funky Vinyasa Yoga to Music | -70.5h | 2025-08-27T10:00:00-07:00 | 2025-08-24T11:30:00-07:00 | 51089 |
| Dust & Dreams: Paint in the Sun | -70.5h | 2025-08-27T14:00:00-07:00 | 2025-08-24T15:30:00-07:00 | 51405 |
| Naked Pub Crawl Stop | -70.5h | 2025-08-27T11:30:00-07:00 | 2025-08-24T13:00:00-07:00 | 51978 |
| Shrimpy Hour | -70.5h | 2025-08-27T16:00:00-07:00 | 2025-08-24T17:30:00-07:00 | 53744 |
| DJ Lost Desert Live in the Garden | -70.5h | 2025-08-27T13:00:00-07:00 | 2025-08-24T14:30:00-07:00 | 53260 |
| Champagne & Donuts | -70.0h | 2025-08-27T10:00:00-07:00 | 2025-08-24T12:00:00-07:00 | 50908 |
| Intro to the Enneagram | -70.0h | 2025-08-27T11:00:00-07:00 | 2025-08-24T13:00:00-07:00 | 51646 |
| Senior Sex Chat | -70.0h | 2025-08-27T11:00:00-07:00 | 2025-08-24T13:00:00-07:00 | 51888 |
| Flavor Tripping | -70.0h | 2025-08-27T14:00:00-07:00 | 2025-08-24T16:00:00-07:00 | 52075 |
| Playa Xxxmas | -70.0h | 2025-08-27T19:00:00-07:00 | 2025-08-24T21:00:00-07:00 | 53867 |
| Playa Vybz: Reggae, Afrobeats & Hip Hop | -69.0h | 2025-08-27T13:00:00-07:00 | 2025-08-24T16:00:00-07:00 | 51541 |
| Tune In: Card Readings | -69.0h | 2025-08-27T12:00:00-07:00 | 2025-08-24T15:00:00-07:00 | 51893 |
| Mad Hatter Tea Party Adventure | -69.0h | 2025-08-27T15:00:00-07:00 | 2025-08-24T18:00:00-07:00 | 53845 |
| Alien Welcoming Party | -69.0h | 2025-08-27T20:00:00-07:00 | 2025-08-24T23:00:00-07:00 | 54372 |
| Dark Fae Take Over the Day | -69.0h | 2025-08-27T14:00:00-07:00 | 2025-08-24T17:00:00-07:00 | 54650 |
| The Self-Care Saloon | -68.0h | 2025-08-27T12:00:00-07:00 | 2025-08-24T16:00:00-07:00 | 54235 |
| Gin & Juice Party | -67.0h | 2025-08-27T14:00:00-07:00 | 2025-08-24T19:00:00-07:00 | 52336 |
| The Mighty Ice Throne — We Gift u Frozen Buns | -67.0h | 2025-08-27T12:00:00-07:00 | 2025-08-24T17:00:00-07:00 | 53629 |
| Purple Jungle Golden Hour Party | -66.0h | 2025-08-27T16:00:00-07:00 | 2025-08-24T22:00:00-07:00 | 52571 |
| Legends in Music Party | -66.0h | 2025-08-26T20:00:00-07:00 | 2025-08-24T02:00:00-07:00 | 53660 |
| Buttplug Tug of Wars | -59.0h | 2025-08-26T15:45:00-07:00 | 2025-08-24T04:45:00-07:00 | 51998 |
| Flog Me Maybe | -47.2h | 2025-08-26T15:00:00-07:00 | 2025-08-24T15:45:00-07:00 | 53451 |
| Bollywood Dance Workshop | -47.2h | 2025-08-26T11:30:00-07:00 | 2025-08-24T12:15:00-07:00 | 53511 |
| Get Your Improv On | -47.0h | 2025-08-28T13:00:00-07:00 | 2025-08-26T14:00:00-07:00 | 51452 |
| Pyro Pirate Party | -47.0h | 2025-08-26T21:00:00-07:00 | 2025-08-24T22:00:00-07:00 | 52482 |
| Fuckery Meditation | -47.0h | 2025-08-26T12:00:00-07:00 | 2025-08-24T13:00:00-07:00 | 52689 |
| Couch Yoga - The comfiest yoga on playa | -47.0h | 2025-08-26T10:00:00-07:00 | 2025-08-24T11:00:00-07:00 | 53340 |
| Lucid Future: A guided Visioning Ceremony | -47.0h | 2025-08-26T15:30:00-07:00 | 2025-08-24T16:30:00-07:00 | 53416 |
| Fire Flogging with a Florentine Twist | -47.0h | 2025-08-26T21:00:00-07:00 | 2025-08-24T22:00:00-07:00 | 53506 |
| Wilted Cactus | -47.0h | 2025-08-26T17:00:00-07:00 | 2025-08-24T18:00:00-07:00 | 54034 |
| Sacred Breath: Move and Flow | -47.0h | 2025-08-26T11:00:00-07:00 | 2025-08-24T12:00:00-07:00 | 54090 |
| Queer Shibari Workshop | -47.0h | 2025-08-26T13:30:00-07:00 | 2025-08-24T14:30:00-07:00 | 54672 |
| Sacred Surrender, A Tantric Playshop | -46.5h | 2025-08-26T11:00:00-07:00 | 2025-08-24T12:30:00-07:00 | 52202 |
| Hilarious Breathing | -46.5h | 2025-08-26T09:30:00-07:00 | 2025-08-24T11:00:00-07:00 | 54549 |
| Tango Alchemy | -46.0h | 2025-08-26T14:00:00-07:00 | 2025-08-24T16:00:00-07:00 | 52076 |
| SmutTEA: Smut Reading & Tea Service | -46.0h | 2025-08-26T14:00:00-07:00 | 2025-08-24T16:00:00-07:00 | 52921 |
| Create a soulmate amulet - Ukrainian motanka | -46.0h | 2025-08-26T12:00:00-07:00 | 2025-08-24T14:00:00-07:00 | 53148 |
| Bacon, Booze and Beats! | -46.0h | 2025-08-26T14:00:00-07:00 | 2025-08-24T16:00:00-07:00 | 53630 |
| Sultry Tea & Coffee Breakfast! | -46.0h | 2025-08-26T10:30:00-07:00 | 2025-08-24T12:30:00-07:00 | 53797 |
| Baptism: UnCage Yourself | -46.0h | 2025-08-26T10:00:00-07:00 | 2025-08-24T12:00:00-07:00 | 53865 |
| Sunset Sound Ceremony & Somatic Ecstatic Dance | -46.0h | 2025-08-26T18:00:00-07:00 | 2025-08-24T20:00:00-07:00 | 53947 |
| DUSTY QUESAWEINERS! | -45.5h | 2025-08-26T12:00:00-07:00 | 2025-08-24T14:30:00-07:00 | 52815 |
| Kenfucky Derby | -45.5h | 2025-08-26T15:30:00-07:00 | 2025-08-24T18:00:00-07:00 | 50843 |
| Spicy Chocolate Wisdom | -45.0h | 2025-08-26T17:00:00-07:00 | 2025-08-24T20:00:00-07:00 | 51874 |
| The First Running of the Burntucky Derby! | -45.0h | 2025-08-26T14:00:00-07:00 | 2025-08-24T17:00:00-07:00 | 52261 |
| Corporate Asshole Party | -45.0h | 2025-08-26T16:00:00-07:00 | 2025-08-24T19:00:00-07:00 | 54649 |
| Haircut Roulette | -44.0h | 2025-08-26T13:00:00-07:00 | 2025-08-24T17:00:00-07:00 | 51296 |
| Hag's Brew | -44.0h | 2025-08-25T20:00:00-07:00 | 2025-08-24T00:00:00-07:00 | 53264 |
| Fashion Burntique Opening Bash! | -44.0h | 2025-08-26T11:00:00-07:00 | 2025-08-24T15:00:00-07:00 | 53755 |
| Miss Playa 2025 competition | -43.0h | 2025-08-26T14:00:00-07:00 | 2025-08-24T19:00:00-07:00 | 52335 |
| 4th Annual White Wednesday Powder Party! | -43.0h | 2025-08-27T19:00:00-07:00 | 2025-08-26T00:00:00-07:00 | 52502 |
| To Psy, or Not to Psy | -42.0h | 2025-08-25T20:00:00-07:00 | 2025-08-24T02:00:00-07:00 | 54242 |
| Visit the Old World Circus Lounge | -38.5h | 2025-08-26T08:30:00-07:00 | 2025-08-24T18:00:00-07:00 | 53950 |
| Paint a Gnome at our bar! | -37.0h | 2025-08-25T13:00:00-07:00 | 2025-08-24T00:00:00-07:00 | 52521 |
| Burning Man - A Ritual of Liberation | -35.2h | 2025-08-25T15:30:00-07:00 | 2025-08-24T04:15:00-07:00 | 53399 |
| The PlayAlchemist Speaker Series | -34.0h | 2025-08-26T08:00:00-07:00 | 2025-08-24T22:00:00-07:00 | 52160 |
| Alice in Tomorrow Today | -23.0h | 2025-08-25T21:00:00-07:00 | 2025-08-24T22:00:00-07:00 | 51612 |
| Genitalia Dentata | -23.0h | 2025-08-25T14:00:00-07:00 | 2025-08-24T15:00:00-07:00 | 52330 |
| Singing for Scaredy Cats | -23.0h | 2025-08-25T11:00:00-07:00 | 2025-08-24T12:00:00-07:00 | 52714 |
| Embodied Neuro-Alchemy: Yoga & Hypnosis | -23.0h | 2025-08-25T14:00:00-07:00 | 2025-08-24T15:00:00-07:00 | 53089 |
| Full Frontal Activation | -23.0h | 2025-08-25T13:00:00-07:00 | 2025-08-24T14:00:00-07:00 | 53087 |
| Bliss Rx: Get High Without Substances | -23.0h | 2025-08-29T11:00:00-07:00 | 2025-08-28T12:00:00-07:00 | 53146 |
| Sexy by Design: Button ON! | -23.0h | 2025-08-29T13:00:00-07:00 | 2025-08-28T14:00:00-07:00 | 53149 |
| Alchemy of Joy | -23.0h | 2025-08-29T14:00:00-07:00 | 2025-08-28T15:00:00-07:00 | 53151 |
| Slow Flow Vinyasa Yoga | -23.0h | 2025-08-25T12:00:00-07:00 | 2025-08-24T13:00:00-07:00 | 53669 |
| Guided sunrise meditation | -23.0h | 2025-08-25T06:30:00-07:00 | 2025-08-24T07:30:00-07:00 | 54618 |
| Live Music | -22.8h | 2025-08-25T15:45:00-07:00 | 2025-08-24T17:00:00-07:00 | 54281 |
| No Darkwads - Light up your s...t | -22.5h | 2025-08-25T14:00:00-07:00 | 2025-08-24T15:30:00-07:00 | 50822 |
| Sci-Fi Seduction | -22.5h | 2025-08-25T14:00:00-07:00 | 2025-08-24T15:30:00-07:00 | 50934 |
| Sunset Sound Meditation & Herbal Tea Ceremony | -22.5h | 2025-08-25T19:00:00-07:00 | 2025-08-24T20:30:00-07:00 | 53343 |
| Play My Game | -22.0h | 2025-08-25T16:00:00-07:00 | 2025-08-24T18:00:00-07:00 | 51581 |
| Brews and Bootches, Beats too! | -22.0h | 2025-08-25T13:00:00-07:00 | 2025-08-24T15:00:00-07:00 | 51583 |
| Pizza Par-Tay | -22.0h | 2025-08-25T18:00:00-07:00 | 2025-08-24T20:00:00-07:00 | 52531 |
| Naked Pirate Shot Party | -22.0h | 2025-08-25T10:00:00-07:00 | 2025-08-24T12:00:00-07:00 | 52463 |
| Ministry of Industry Party | -22.0h | 2025-08-25T22:00:00-07:00 | 2025-08-25T00:00:00-07:00 | 52468 |
| Sauna Burn | -22.0h | 2025-08-25T22:00:00-07:00 | 2025-08-25T00:00:00-07:00 | 53082 |
| Cosmic journey breathwork | -22.0h | 2025-08-29T09:00:00-07:00 | 2025-08-28T11:00:00-07:00 | 53144 |
| Grand Opening: Immersive Sound Meditation | -22.0h | 2025-08-24T23:00:00-07:00 | 2025-08-24T01:00:00-07:00 | 53626 |
| A Yin Yoga & Tea Ceremony for the Senses | -22.0h | 2025-08-25T22:00:00-07:00 | 2025-08-25T00:00:00-07:00 | 53657 |
| Movie Night: Mandy | -22.0h | 2025-08-25T21:00:00-07:00 | 2025-08-24T23:00:00-07:00 | 53741 |
| Noodle of Destiny | -22.0h | 2025-08-25T16:00:00-07:00 | 2025-08-24T18:00:00-07:00 | 53850 |
| AZUL, HEALING TENT, COMMUNITY SESSIONS | -22.0h | 2025-08-25T16:00:00-07:00 | 2025-08-24T18:00:00-07:00 | 54279 |
| Monday, Drink and Draw Live Nude Sketching, 1pm to | -22.0h | 2025-08-25T13:00:00-07:00 | 2025-08-24T15:00:00-07:00 | 54416 |
| Rocky Horror Picture Show | -21.8h | 2025-08-29T23:45:00-07:00 | 2025-08-29T02:00:00-07:00 | 52283 |
| Camp not a Cult: Ride of the Valkyries | -21.5h | 2025-08-25T18:00:00-07:00 | 2025-08-24T20:30:00-07:00 | 51483 |
| Motown & Meade Monday | -21.5h | 2025-08-25T21:30:00-07:00 | 2025-08-25T00:00:00-07:00 | 53358 |
| Bottles Are Dusty, Our Liquor Is Clean | -21.0h | 2025-08-26T21:00:00-07:00 | 2025-08-26T00:00:00-07:00 | 50817 |
| 11th Annual Super Hero Underwear Party | -21.0h | 2025-08-25T14:00:00-07:00 | 2025-08-24T17:00:00-07:00 | 51415 |
| Planet of [eips] | -21.0h | 2025-08-27T21:45:00-07:00 | 2025-08-27T00:45:00-07:00 | 52984 |
| Black Rock Cinemas - Audition After Party! | -21.0h | 2025-08-26T21:00:00-07:00 | 2025-08-26T00:00:00-07:00 | 53994 |
| The Monaco Presents: The Siren's Song at Sunset | -21.0h | 2025-08-25T19:00:00-07:00 | 2025-08-24T22:00:00-07:00 | 53484 |
| Shiny Slacker Moon Base Party | -21.0h | 2025-08-26T21:00:00-07:00 | 2025-08-26T00:00:00-07:00 | 54270 |
| Ecstatic Dance at Chill Vibez! | -21.0h | 2025-08-28T21:00:00-07:00 | 2025-08-28T00:00:00-07:00 | 54276 |
| Nauti by Nature: The Underwater Disco | -21.0h | 2025-08-25T21:00:00-07:00 | 2025-08-25T00:00:00-07:00 | 54600 |
| Pound some metal | -20.0h | 2025-08-25T12:00:00-07:00 | 2025-08-24T16:00:00-07:00 | 50910 |
| Space Pants Space Dance | -20.0h | 2025-08-26T20:00:00-07:00 | 2025-08-26T00:00:00-07:00 | 51235 |
| Vags & Tags Fire Jam | -20.0h | 2025-08-30T20:00:00-07:00 | 2025-08-30T00:00:00-07:00 | 51591 |
| Movies on the Playa - Black Rock Doc Premiere | -20.0h | 2025-08-27T20:00:00-07:00 | 2025-08-27T00:00:00-07:00 | 53999 |
| DJ Sets | -20.0h | 2025-08-30T22:30:00-07:00 | 2025-08-30T02:30:00-07:00 | 54349 |
| Hot Dogs & Hard Techno Beats | -20.0h | 2025-08-28T22:00:00-07:00 | 2025-08-28T02:00:00-07:00 | 54612 |
| Black Light Body Paint Playroom | -19.5h | 2025-08-26T20:30:00-07:00 | 2025-08-26T01:00:00-07:00 | 54538 |
| Berries & Bass | -19.0h | 2025-08-26T21:00:00-07:00 | 2025-08-26T02:00:00-07:00 | 52770 |
| Playa Postcards! | -19.0h | 2025-08-25T09:00:00-07:00 | 2025-08-24T14:00:00-07:00 | 51775 |
| Cosmic Convergence | -19.0h | 2025-08-27T22:00:00-07:00 | 2025-08-27T03:00:00-07:00 | 53038 |
| Builders Party - Joy of Today | -19.0h | 2025-08-24T21:00:00-07:00 | 2025-08-24T02:00:00-07:00 | 53642 |
| The Man's Tears Happy Hours | -18.0h | 2025-08-30T18:00:00-07:00 | 2025-08-30T00:00:00-07:00 | 51008 |
| FLAMING CORNHOLE | -18.0h | 2025-08-24T20:00:00-07:00 | 2025-08-24T02:00:00-07:00 | 53193 |
| DANCE LOLA, DANCE! | -16.0h | 2025-08-26T22:00:00-07:00 | 2025-08-26T06:00:00-07:00 | 54084 |
| Global Bass and World Dance Music Party! | -15.0h | 2025-08-26T20:00:00-07:00 | 2025-08-26T05:00:00-07:00 | 53530 |
| Message from the universe | -12.0h | 2025-08-25T10:00:00-07:00 | 2025-08-24T22:00:00-07:00 | 51895 |
| PHOTO BOARDS | -12.0h | 2025-08-24T12:00:00-07:00 | 2025-08-24T00:00:00-07:00 | 53168 |
| Organic Hookah in our Air-Conditioned Lounge! | -12.0h | 2025-08-25T14:00:00-07:00 | 2025-08-25T02:00:00-07:00 | 53550 |
| Dusty Muffin Creamery | -11.2h | 2025-08-28T11:15:00-07:00 | 2025-08-28T00:00:00-07:00 | 51271 |
| Group Reiki Practice Drop In & Connect | -11.0h | 2025-08-27T11:00:00-07:00 | 2025-08-27T00:00:00-07:00 | 51342 |
| Spiritual Maintenance Energetic Pit Stop | -11.0h | 2025-08-27T12:00:00-07:00 | 2025-08-27T01:00:00-07:00 | 51404 |
| Tour of Airport (88NV) | -11.0h | 2025-08-27T11:00:00-07:00 | 2025-08-27T00:00:00-07:00 | 52171 |
| Whistle Wizardry Workshop | -11.0h | 2025-08-27T15:00:00-07:00 | 2025-08-27T04:00:00-07:00 | 52711 |
| Neuroscience: Mindset for the Burn | -11.0h | 2025-08-29T11:00:00-07:00 | 2025-08-29T00:00:00-07:00 | 53980 |
| Stoicism- How Yesterday’s Ideas Help Us Today | -11.0h | 2025-08-29T11:00:00-07:00 | 2025-08-29T00:00:00-07:00 | 54552 |
| I-Ching and Tarot Card readings | -10.8h | 2025-08-25T09:00:00-07:00 | 2025-08-24T22:15:00-07:00 | 54413 |
| I-Ching and Tarot Card readings | -10.8h | 2025-08-25T09:00:00-07:00 | 2025-08-24T22:15:00-07:00 | 54412 |
| Tantric Movement Ceremony: Divine Dfloor | -10.5h | 2025-08-26T11:30:00-07:00 | 2025-08-26T01:00:00-07:00 | 51115 |
| Tribute to Lost Musicians Concert | -10.5h | 2025-08-28T16:00:00-07:00 | 2025-08-28T05:30:00-07:00 | 51230 |
| Spin City Poi | -10.5h | 2025-08-28T15:00:00-07:00 | 2025-08-28T04:30:00-07:00 | 51377 |
| Premium Sake Tasting | -10.5h | 2025-08-28T16:00:00-07:00 | 2025-08-28T05:30:00-07:00 | 51194 |
| Playa Choir Performance | -10.5h | 2025-08-31T11:00:00-07:00 | 2025-08-31T00:30:00-07:00 | 51958 |
| Sunset Cacao & Song Singing Circle | -10.5h | 2025-08-26T20:00:00-07:00 | 2025-08-26T09:30:00-07:00 | 52630 |
| Playa Match: Blindfold Edition | -10.5h | 2025-08-28T17:30:00-07:00 | 2025-08-28T07:00:00-07:00 | 53085 |
| Welcome Pumaccinos | -10.0h | 2025-08-24T19:30:00-07:00 | 2025-08-24T09:30:00-07:00 | 51506 |
| CHILL YOUR NECK, NOT YOUR VIBE | -10.0h | 2025-08-27T12:00:00-07:00 | 2025-08-27T02:00:00-07:00 | 53059 |
| Christmas Brunch with The Pink Secretary | -10.0h | 2025-08-31T11:00:00-07:00 | 2025-08-31T01:00:00-07:00 | 53224 |
| PAM tent-Pendant Designing-Know your WHY | -10.0h | 2025-08-28T23:00:00-07:00 | 2025-08-28T13:00:00-07:00 | 53678 |
| Fire Ritual & Enigma Beats | -9.5h | 2025-08-28T17:00:00-07:00 | 2025-08-28T07:30:00-07:00 | 54514 |
| Get Juiced | -9.0h | 2025-08-25T15:00:00-07:00 | 2025-08-25T06:00:00-07:00 | 51036 |
| Sensual Hotdog Eating Contest | -9.0h | 2025-08-29T18:00:00-07:00 | 2025-08-29T09:00:00-07:00 | 51674 |
| Yerba Mate Dub | -9.0h | 2025-08-24T10:30:00-07:00 | 2025-08-24T01:30:00-07:00 | 51795 |
| NO PANTS PARTY | -9.0h | 2025-08-25T09:00:00-07:00 | 2025-08-25T00:00:00-07:00 | 53042 |
| Breakfast Clubbing | -8.0h | 2025-08-29T08:00:00-07:00 | 2025-08-29T00:00:00-07:00 | 51826 |
| Disorient Express | -8.0h | 2025-08-26T20:00:00-07:00 | 2025-08-26T12:00:00-07:00 | 51825 |
| Glam Clams Recovery Lounge | -8.0h | 2025-08-25T12:00:00-07:00 | 2025-08-25T04:00:00-07:00 | 52138 |
| Welcome Home Party! | -8.0h | 2025-08-24T08:00:00-07:00 | 2025-08-24T00:00:00-07:00 | 53525 |
| DUSTY AFTER PARTY | -8.0h | 2025-08-28T08:00:00-07:00 | 2025-08-28T00:00:00-07:00 | 53848 |
| DUSTY AFTER PARTY | -8.0h | 2025-08-28T08:00:00-07:00 | 2025-08-28T00:00:00-07:00 | 53848 |
| Daily Kombucha Watering Hole | -6.0h | 2025-08-25T23:00:00-07:00 | 2025-08-25T17:00:00-07:00 | 52736 |
| Vinegar Vignettes | -6.0h | 2025-08-27T11:00:00-07:00 | 2025-08-27T05:00:00-07:00 | 52740 |
| Critical Tits Body Painting | -5.0h | 2025-08-29T09:00:00-07:00 | 2025-08-29T04:00:00-07:00 | 50961 |
| Watergun Assassin Game 3:00 Sector | -0.2h | 2025-08-25T12:00:00-07:00 | 2025-08-25T11:45:00-07:00 | 52194 |

## Pattern Analysis

Common patterns observed:
- Many events have end times set to August 24th while start times are later dates
- Some events have end times that are exactly 24 hours before the start time
- Events spanning multiple days seem particularly affected

### Duration Range Distribution

- Less than -100h: 27 events
- -100h to -50h: 54 events
- -50h to -24h: 35 events
- -24h to 0h: 91 events

## Most Extreme Cases

Top 10 events with most negative duration:

1. **UKRAINIAN FASHION: FLOWER CROWN MAKING**: -1462.5 hours
   - Start: 2025-08-26T15:00:00-07:00
   - End: 2025-06-26T16:30:00-07:00

2. **Last dance party!**: -191.8 hours
   - Start: 2025-09-01T17:30:00-07:00
   - End: 2025-08-24T17:45:00-07:00

3. **Phantasmagoria bar**: -181.0 hours
   - Start: 2025-09-01T13:00:00-07:00
   - End: 2025-08-25T00:00:00-07:00

4. **Temple Narcotics Anonymous Unity Meeting**: -167.0 hours
   - Start: 2025-08-31T09:00:00-07:00
   - End: 2025-08-24T10:00:00-07:00

5. **B2B**: -165.0 hours
   - Start: 2025-08-31T06:00:00-07:00
   - End: 2025-08-24T09:00:00-07:00

6. **Deja Boom**: -164.0 hours
   - Start: 2025-08-30T22:00:00-07:00
   - End: 2025-08-24T02:00:00-07:00

7. **Sake Bomb Sunday**: -163.0 hours
   - Start: 2025-08-31T12:15:00-07:00
   - End: 2025-08-24T17:15:00-07:00

8. **Come dance the night away with us**: -161.0 hours
   - Start: 2025-08-30T22:00:00-07:00
   - End: 2025-08-24T05:00:00-07:00

9. **Sluttly MOOP Walk**: -142.0 hours
   - Start: 2025-08-30T14:00:00-07:00
   - End: 2025-08-24T16:00:00-07:00

10. **Slutty Sledding Saturday!**: -142.0 hours
   - Start: 2025-08-30T18:00:00-07:00
   - End: 2025-08-24T20:00:00-07:00

