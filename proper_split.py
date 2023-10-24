#!/usr/bin/python3

trains=[]
tests=[]
words_trains=[]
with open("/home/ananth/Downloads/SSN_TDSC/documents/complete_text","r") as all_text:
     f=all_text.readlines()
     random.shuffle(f)
     words=f[0].split(" ")
     words[-1]=words[-1][0:len(words[-1])-1]
     for i in range(len(f)):
         words=f[i].split(" ")
         words[-1]=words[-1][0:len(words[-1])-1]
         flag=0
         for j in words:
             if j not in words_trains:
                flag=1
                break
         if flag==0:
            tests.append(f[i])
         elif f[i] not in trains: 
              trains.append(f[i])  
              for i in f[i].split(" "):
                  if '\n' in i: words_trains.append(i[0:len(i)-1])
                  else: words_trains.append(i)
                 
                
with open("./text","r") as text:
     all_lines=text.readlines()
     with open("./data/train/text","a") as t1:
          with open("./data/test/text","a") as t2:
              for i in all_lines:
                  if i.split("	")[1] in trains:
                     t1.write(i)
                  else:
                     t2.write(i)
