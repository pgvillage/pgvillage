import hashlib

def hashnum(s, n):
    # return a number module n based on the hash of a string
    try:
        n = int(n)
    except ValueError:
        return 'Invalid n value for hashnum: {0}'.format(n)
    return str(abs(int(hashlib.md5(s.encode()).hexdigest(),16)) % n)

class FilterModule(object):
    def filters(self):
        return {
            'hashnum': hashnum
        }
