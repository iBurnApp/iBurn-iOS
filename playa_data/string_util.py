

def cleanString(string):
    return string.lower().replace(", the", "").replace("the ", "").replace(", a", "").replace("a ", "").strip()
