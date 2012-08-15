

def cleanString(string):
    return string.lower().replace("&", "").replace("and", "").replace(", the", "").replace("the ", "").replace(", a", "").replace("a ", "").strip()
