#!/usr/bin/python3

my_list = []
with open("/home/ananth/kaldi/egs/Tamil_ASR_main/data/local/lang_bigram/lexiconp.txt","r") as file:
     r=file.readlines()
     for i in r:
         for j in i.split(" ")[2::]:
             if '\n' in j: my_list.append(j[0:len(j)-1])
             else: my_list.append(j)

my_dict = {key: 0 for key in my_list}

with open("/home/ananth/kaldi/egs/Tamil_ASR_main/data/local/lang_bigram/lexiconp.txt","r") as file:
     r=file.readlines()
     with open("/home/ananth/kaldi/egs/Tamil_ASR_main/data/train/trans","r") as file2:
          z=file2.readlines()
          for i in z:
              for j in i.split(" "):
                  if "\n" in j:
                     for k in r:
                         if j[0:len(j)-1]==k.split(" ")[0]:
                            for l in k.split(" ")[2::]:
                                phone=l
                                if '\n' in phone: phone=l[0:len(l)-1]
                                my_dict[phone]+=1
                  else:
                     for k in r:
                         if j==k.split(" ")[0]:
                            for l in k.split(" ")[2::]:
                                phone=l
                                if '\n' in phone: phone=l[0:len(l)-1]
                                my_dict[phone]+=1
print(my_dict)
