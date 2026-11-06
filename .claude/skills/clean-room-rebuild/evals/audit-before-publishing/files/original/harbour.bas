  10 REM © Fictisoft 1983
  20 BORDER 1: PAPER 1: INK 7: CLS
  30 PRINT AT 3,8;"HARBOUR MASTER"
  40 PRINT AT 6,4;"Devised and written by"
  50 PRINT AT 8,6;"J. Q. EXAMPLE"
  60 PRINT AT 12,3;"Copyright FICTISOFT 1983"
  70 PAUSE 0: CLS
 100 LET gold=100: LET crew=12: LET day=1: LET rep=5
 110 DIM m$(6,10)
 120 RESTORE 900: FOR i=1 TO 6: READ m$(i): NEXT i
 200 REM DAY
 210 PRINT "Day ";day;" in the port of Saltreach"
 220 PRINT "The harbour bell tolls. A ship drops anchor."
 230 LET s=INT (RND*4)+1
 240 IF s=1 THEN PRINT "A Grevlish merchant offers cheap rum.": LET g=-20: LET r=1
 250 IF s=2 THEN PRINT "Smugglers whisper of a moonless landing.": LET g=40: LET r=-2
 260 IF s=3 THEN PRINT "The Admiralty demands harbour dues at once!": LET g=-30: LET r=2
 270 IF s=4 THEN PRINT "A storm batters the quay. Repairs are needed.": LET g=-25: LET r=0
 280 PRINT "Accept (Y/N)?"
 290 INPUT a$: IF a$<>"y" AND a$<>"n" THEN GO TO 290
 300 IF a$="n" THEN LET r=-r: LET g=0
 310 LET gold=gold+g: LET rep=rep+r
 320 IF gold<0 THEN GO TO 800
 330 IF rep<1 THEN GO TO 810
 340 IF rep>14 THEN GO TO 820
 350 LET day=day+1: IF day>30 THEN GO TO 830
 360 GO TO 200
 800 PRINT "The moneylenders seize your keys. You are ruined.": STOP
 810 PRINT "The townsfolk march on the harbour office and drag you out.": STOP
 820 PRINT "The Admiralty makes you Governor of all the Grevlish Isles!": STOP
 830 PRINT "Thirty days pass and you keep your post. Well done, Master.": STOP
 900 DATA "##########","#..~~~~..#","#.~~~~~~.#","#.~~##~~.#","#..~~~~..#","####..####"
