# PEP-0238 floor division : submitted

# PEP-310[1-4] no effect
# PEP-3105 print function : major effect
# PEP-3106 revamping dict methods : minor effect
# PEP-3107 no effect
# PEP-3108 standard library reorg : urllib, reduce and itertools + following
find -type f -name '*.py' -exec sed -i 's/\(string\.\)\(\(low\|upp\)ercase|letters\)/\1ascii_\2/g' '{}' \;
# PEP-3109 no effect
# PEP-3110 catching exceptions : following
2to3 -f except -wn pwnlib pwn docs extra examples
2to3 -f except -dwn pwnlib pwn docs extra examples
# PEP-3111 [raw_]input() : no effect because of pwnlib/term/readline.py
# PEP-3112 b'' : to do by hand
# PEP-3113 tuple parameters : done :)
# PEP-3114 iterator.next() : to do by hand afterwards + following [submitted]
2to3 -f next -wn pwnlib pwn docs extra examples
2to3 -f next -dwn pwnlib pwn docs extra examples
# PEP-3115 no effect
# PEP-3116 _io and stuff : mostly replacing `file` with `open`, also affecting pwnlib/term/
# PEP-31{17..26} no effect
# PEP-3127 integer literals : following
2to3 -f numliterals -wn pwnlib pwn docs extra examples
2to3 -f numliterals -dwn pwnlib pwn docs extra examples
# PEP-3155 __qualname__ : minor effect

2to3 -f map -wn pwnlib/shellcraft/registers.py pwnlib/commandline/common.py
find pwnlib/shellcraft/templates -name '*.asm' -exec sed -i 's/(int, \?long)/six.integer_types/g' '{}' \;
