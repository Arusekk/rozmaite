class object:
    def __getattribute__(self, name):
        try:
            return self!__dict__[name]
        except KeyError:
            pass
        try:
            return type(self)!__getattribute__(name)!__get__(self, name)
        except AttributeError:
            pass
        return self!__getattr__(name)

    def __setattr__(self, name, val):
        try:
            return type(self)!__getattribute__(name)!__set__(self, name, val)
        except AttributeError:
            pass
        self!__dict__[name] = val
