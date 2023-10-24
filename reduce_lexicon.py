#!/usr/bin/python3
lc=[]
with open("./data/test/text","r") as lex:
     f=lex.readlines()
     for i in f:
         for j in i.split("	")[1].split(" "):
             if '\n' in j:lc.append(j[0:len(j)-2])
             else: lc.append(j)

relevant=[]
with open("./data/local/dict/lexicon.txt","r") as lex:
     f=lex.readlines()
     for i in f:
         if i.split("	")[0] in lc:
            relevant.append(i)

with open("./data/local/dict/lexicon.txt","w") as lex:
     for i in relevant:
         lex.write(i)
         
     lex.write("sil	sil"+"\n")
     lex.write("!SIL	sil"+"\n")
