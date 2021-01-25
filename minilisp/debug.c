struct frame {
  struct frame *bk;
  union obj *rbx;
  void *retaddr;
};


struct pair {
  union obj *car, *cdr;
};

union obj {
  struct pair o_pair;
  char o_string[0];
};

#define caar car->o_pair.car
#define cdar car->o_pair.cdr
#define cadr cdr->o_pair.car
#define cddr cdr->o_pair.cdr

union obj* caar_(struct pair* p) {
  return p->caar;
}
union obj* cdar_(struct pair* p) {
  return p->cdar;
}
union obj* cadr_(struct pair* p) {
  return p->cadr;
}
union obj* cddr_(struct pair* p) {
  return p->cddr;
}

long write(int, const char*, unsigned long);

void displaystring(const char*);
void display(union obj* o, union obj* tre);
void displaypair(struct pair* p, union obj* tre) {
  write(1, "(", 1);
  display(p->car, tre);
  write(1, " . ", 3);
  display(p->cdr, tre);
  write(1, ")", 1);
}
void displaylist(struct pair* p, union obj* tre) {
  write(1, "(", 1);
  for (;;) {
    display(p->car, tre);
    if (!p->cdr)
      break;
    else if (p->cdr > tre) {
      write(1, " . ", 3);
      display(p->cdr, tre);
      break;
    }
    write(1, " ", 1);
  }
  write(1, ")", 1);
}
void display(union obj* o, union obj* tre) {
  if (o == (union obj*)0)
    write(1, "()", 5);
  else if (o < tre)
    displaypair(&o->o_pair, tre);
  else
    displaystring(o->o_string);
}
