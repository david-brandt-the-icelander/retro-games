  10 REM LOCK KEEPER (C) INVENTASOFT 1984
  15 LET h=0
  20 BORDER 4: PAPER 4: INK 0: CLS
  30 PRINT AT 2,10;"LOCK KEEPER"
  40 PRINT AT 5,1;"Keep the Marrowdeep Cut afloat"
  50 PRINT AT 9,6;"by R. T. PLACEHOLDER"
  60 PRINT AT 12,2;"(C) 1984 INVENTASOFT LIMITED"
  70 PRINT AT 18,5;"Press I for the rules"
  80 PAUSE 0: IF INKEY$="i" THEN GO SUB 700
 100 LET w=5: LET c=50: LET g=3: LET d=1
 110 DIM t(4): DIM u(4): DIM v(4)
 120 RESTORE 900: FOR i=1 TO 4: READ t(i),u(i),v(i): NEXT i
 200 CLS: PRINT "Day ";d;" at Lock Seven, Marrowdeep"
 210 PRINT "Water ";w;"  Coins ";c;"  Goodwill ";g
 220 LET b=INT (RND*4)+1
 230 IF b=1 THEN PRINT "A painted narrowboat toots its horn."
 240 IF b=2 THEN PRINT "A coal barge wallows low in the water."
 250 IF b=3 THEN PRINT "Pleasure cruisers sing as they drift up."
 260 IF b=4 THEN PRINT "The Pellandine inspector wants passage."
 270 PRINT "Open gates (O) or keep shut (K)?"
 280 LET a$=INKEY$: IF a$<>"o" AND a$<>"k" THEN GO TO 280
 290 IF a$="o" THEN LET w=w-u(b): LET c=c+t(b): LET g=g+v(b)
 300 IF a$="k" THEN LET g=g-1
 310 IF INT (RND*3)=0 THEN LET w=w+2: PRINT "Rain drums on the towpath. The pound fills."
 320 IF w>9 THEN LET w=9
 330 IF w<1 THEN LET e=1: GO TO 800
 340 IF c<0 THEN LET e=2: GO TO 800
 350 IF g<1 THEN LET e=3: GO TO 800
 360 LET d=d+1: IF d>20 THEN LET e=4: GO TO 800
 370 PRINT "Press a key for the next day": PAUSE 0
 380 GO TO 200
 700 CLS: PRINT "Boats come to your lock each day."
 710 PRINT "Let them through for tolls, but"
 720 PRINT "every lockful drains the pound."
 730 PRINT "Turn them away and folk grumble."
 740 PAUSE 0: RETURN
 800 IF e=1 THEN PRINT "The pound runs dry and the boats sit in the mud."
 810 IF e=2 THEN PRINT "The bailiffs take your lock-house and your kettle."
 820 IF e=3 THEN PRINT "The boatmen petition Pellandine and you are dismissed."
 830 IF e=4 THEN PRINT "Twenty days kept well. You retire to a cottage by the Cut."
 840 IF d>h THEN LET h=d
 850 PRINT "Longest service: ";h;" days"
 860 PAUSE 0: GO TO 20
 900 DATA 3,1,1,6,2,0,2,1,1,-8,1,2
