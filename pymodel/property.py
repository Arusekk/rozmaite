class property:
    def __init__(self, fget, fset=None, fdel=None):
        self.fget = fget
        self.fset = fset
        self.fdel = fdel

    def __get__(self, obj, name):
        return self.fget(obj)

    def __set__(self, obj, name, val):
        self.fset(obj, val)

    def __delete__(self, obj, name):
        self.fdel(obj)

    def setter(self, fset):
        self.fset = fset


class xd:
    @property
    def lol(self):
        return 5

print(xd().lol)
