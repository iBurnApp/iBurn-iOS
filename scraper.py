#!/usr/bin/python

# Scrapes data from the burningman website, and serializes it into json

import lxml.html
import urllib
import sys
import re
import urllib2
import json

class Pointer(object):

    def __init__(self, pointer):
        self.p = pointer

    @property
    def t(self):
        return self.p.tail

    def has(self, strings):
        for string in strings:
            if self.t.find(string) >= 0:
                return string
        return None

    def inct(self, num=1):
        for i in range(num):
            self.p = self.p.getnext()
        return self.p.tail

    def incc(self, num=1):
        for i in range(num):
            self.p = self.p.getnext()
        return self.p.text_content()

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


class Honorarium(object):

    URL = "http://www.burningman.com/installations/11_art_honor.html"
    ROOT_URL = "http://www.burningman.com"

    def _parse_artist(self, artist):
        ret = {}
        b = Pointer(artist.getnext())

        ret["image_url"] = self.ROOT_URL + artist.xpath("//img")[0].get("src")
        ret["title"] = b.p.text_content()
        ret["artists"] = b.inct()
        ret["artist_location"] = b.inct()
        if not ret["artist_location"]:
            b.inct()
        b.inct(2)

        ret["description"], ret["contact"], ret["url"] = '','',''
        while b.t is not None and b.has(["Contact", "URL", "top"]) is None:
            ret["description"] += b.t
            data = b.inct(2)

        while b.t is not None:
            t = b.has(["Contact", "URL"])
            if t is None:
                break
            ret[t.lower()] = b.incc()
            if b.t is not None:
                b.incc()


        for key, value in ret.iteritems():
            ret[key] = _clean_string(value)

        return ret

    def get_data(self):
        root = lxml.html.parse(self.URL).getroot()
        artists = root.xpath('//span[@class="imageright"]')
        return [self._parse_artist(i) for i in artists]

class Camp(object):

    PROXY_URL = "http://blog.burningman.com/ctrl/themecamps/"
    ROOT_URL = "http://www.burningman.com"

    def get_index(self):
        return list("ABCDEFGHIJKLMNOPQRSTUVXYZ#")

    def _parse_camps(self, camp):
        b = Pointer(camp.getnext().getchildren()[0])
        ret = {}
        ret["name"] = b.p.text_content()
        b.inct()

        ret["description"] = ""
        while b.t is not None and b.has(["Hometown", "Contact", "Url"]) is None:
            ret["description"] += b.t
            data = b.inct()

        if b.has(["Hometown"]) is not None:
            ret["hometown"] = b.t[10:]
            b.inct()

        ret["contact"], ret["url"] = '', ''
        while b.t is not None:
            t = b.has(["Contact", "URL"])
            if t is None:
                break
            ret[t.lower()] = b.incc()

            if b.t is not None:
                b.incc()

        for key, value in ret.iteritems():
            ret[key] = _clean_string(value)

        return ret

    def get_data(self):
        opener = urllib2.build_opener()

        results = []
        for index in self.get_index():
            url = self.PROXY_URL+"?job=getData&yy=2011&ci=%s" % index
            req = urllib2.Request(url)
            f = opener.open(req)
            data = json.loads(f.read()[1:-1])[u"campData"]
            data = data.replace("<br>", "<br/>")

            root = lxml.html.fromstring(data)
            camps = root.xpath('//div/div')
            
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
    print json.dumps(data)
