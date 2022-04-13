import math
import re

millnames = ['','k','M','G','T', 'P']

def unhuman(s):
    # return a number from a human readable number
    # like 1k would be 1000
    try:
        upper_millnames = [n.upper() for n in millnames]
        match = re.match(r"([0-9.]+)\s*([a-z]+)?",s, re.I)
        digits = match.group(1)
        factors = match.group(2)
        index = 0
        if factors:
            for factor in factors:
                index += upper_millnames.index(factor.upper())
        return round(float(digits) * 2**(index*10))
    except Exception as err:
        return 'ERROR: Cannot unhuman {}: {}'.format(s, err)
    
def human(n, digits=0):
    # return a human readable string
    # like 1000 would be 1k
    n = float(n)
    i = 0
    while n >= 1024:
        i += 1
        n = n / 1024
    return '{0:.{1}f}{2}'.format(n, digits, millnames[i])

def percent(n, f=100, minimum=0, digits=0):
    result = float(n) * float(f) / 100
    if result < float(minimum):
        return minimum
    return '{0:.{1}f}'.format(result, digits)

class FilterModule(object):
    def filters(self):
        return {
            'human': human,
            'unhuman': unhuman,
            'percent': percent
        }
