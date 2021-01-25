b paren
commands
p (char*)$rsi
end

b minilisp.S:103
commands
p display($rax, $r12)
end

b minilisp.S:145
commands
p display($rax, $r12)
p *(struct frame*)$rbp
end

r
