struct a {double x1; char x2;};
struct b {int y1; struct a y2[3];};

struct b p;

void sub1(void) {
  int i;
  i = p.y2[1].x2;
  p.y1 = i;
}

void sub2(void) {
  char i;
  i = p.y2[1].x2;
  p.y1 = i;
}

void sub3(void) {
  char i;
  int j;
  i = p.y2[1].x2;
  j = i;
  p.y1 = j;
}

int main()
{
  struct b q;
  q.y1 = 1;
  q.y2[0].x1 = 0.0;
  q.y2[0].x2 = 'a';
  q.y2[1].x1 = 0.0;
  q.y2[1].x2 = 'a';
  q.y2[2].x1 = 0.0;
  q.y2[2].x2 = 'a';
  char i;
  int j;
  i = q.y2[1].x2;
  j = i;
  q.y1 = j;
}
