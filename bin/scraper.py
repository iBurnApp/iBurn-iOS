#!/usr/bin/python

# Scrapes data from the burningman website, and serializes it into json

import lxml.html
import lxml.html.soupparser
import urllib
import sys
import re
import urllib2
import json
import re

def _clean_string(str):
    if str:
        str = re.sub(r'^[\n\t\s]+', '', str)
        str = re.sub(r'[\n\t\s]+$', '', str)
        str = str.replace(" (dot) ", ".")
        str = str.replace(" (at) ", "@")
        str = re.sub(r"[\n\t\s]+\s+[\n\t\s]+", "\n\n", str)
        if str.find("by ") == 0:
            str = str[4:]
            str = str.split(", ")
    return str

def _parse_xml(xml):
    parsed_data = []
    for p in xml.iterchildren():
        if p.text is None:
            data = lxml.html.tostring(p, encoding=unicode)
        else:
            data = lxml.html.tostring(p, method='text', encoding=unicode)
        data = re.sub(r"^<br>", "", data)\
            .replace("<p>", "\n")\
            .replace("<div style=\"clear:both\"></div>", "")
        data = data.encode("utf-8")
        parsed_data.append(data)
    return parsed_data

def _request(url, element):
    #print url
    opener = urllib2.build_opener()
    req = urllib2.Request(url)
    f = opener.open(req)
    data = f.read()[1:-1]
    data = json.loads(data)
    data = data[element]
    data = re.sub(r"<script[\w\s=\/\"\n{}>:,;'-\.#]*</script>", "", data, flags=re.MULTILINE)
    root = lxml.html.soupparser.fromstring(data)
    return root

class Honorarium(object):

    # http://www.burningman.com/installations/art_honor.html
    PROXY_URL = "http://blog.burningman.com/ctrl/art/?job=getData&yy=2013&artType=H"

    def _parse_artist(self, artist):
        ret = {}

        parsed_data = _parse_xml(artist)[2:]

        ret["image_url"] = artist.xpath("//img")[0].get("src")
        ret["title"] = parsed_data[0]
        ret["artists"] = parsed_data[1].replace("by ", "")
        ret["artist_location"] = parsed_data[2]

        if "addthis" not in parsed_data[5]:
            ret["description"] = parsed_data[5]
        else:
            ret["description"] = ""

        i = 0
        while i < len(parsed_data):
            content = parsed_data[i]
            if content.find("URL:") == 0:
                i += 1
                ret["url"] = parsed_data[i]
            elif content.find("Contact:") == 0:
                i += 1
                ret["contact"] = parsed_data[i]
            elif "<div" not in content and "addthis" not in content and "</p>" not in content and "script" not in content:
                ret["description"] += " " + content
            i += 1

        for key, value in ret.iteritems():
            ret[key] = _clean_string(value)

        return ret

    def get_data(self):
        root = _request(self.PROXY_URL, "artData")
        artists = root.xpath('//div[@class="artlisting"]')
        return [self._parse_artist(i) for i in artists]


class Camp(object):

    PROXY_URL = "http://blog.burningman.com/ctrl/themecamps/"
    ROOT_URL = "http://www.burningman.com"

    def get_index(self):
        #return list("ABCDEFGHIJKLMNOPQRSTUVWXYZ#")
        return list("W")

    def _parse_camps(self, camp):
        c = camp
        #c = camp.getnext()
        #print c.text_content().encode("utf-8")
        parsed_data = []

        if c is None:
            return

        parsed_data = _parse_xml(c)

        ret = {}
        i = 0
        parsing_desc = False
        while i < len(parsed_data):
            content = parsed_data[i]
            if i == 0:
                ret["name"] = content
                parsing_desc = True
            elif content.find("Hometown:") == 0:
                parsing_desc = False
                ret["hometown"] = content[10:]
            elif content.find("URL:") == 0:
                parsing_desc = False
                i += 1
                ret["url"] = parsed_data[i]
            elif content.find("http://") == 0:
                parsing_desc = False
                ret["url"] = content
            elif content.find("Contact:") == 0:
                parsing_desc = False
                i += 1
                ret["contact"] = parsed_data[i]
            elif parsing_desc:
                if "description" not in ret:
                    ret["description"] = ""
                ret["description"] += content
            else:
                print "ERROR: %s %s" % (i, content)
            i += 1

        for key, value in ret.iteritems():
            ret[key] = _clean_string(value)
        return ret

    def get_data(self):
        results = []
        for index in self.get_index():
            root = _request(self.PROXY_URL+"?job=getData&yy=2013&ci=%s" % index, "campData")
            camps = root.xpath('//div[@class="camp"]')
            results.extend([self._parse_camps(i) for i in camps])
        return results

if __name__ == "__main__":

    if len(sys.argv) < 2 or sys.argv[1] not in ["camps", "honorarium"]:
        print "Usage: scraper.py <camps|honorarium>"
        sys.exit(0)
    if sys.argv[1] == "camps":
        Class = Camp
    elif sys.argv[1] == "honorarium":
        Class = Honorarium

    h = Class()
    data = h.get_data()
    print json.dumps(data, ensure_ascii=False)
    #print json.dumps(data)
