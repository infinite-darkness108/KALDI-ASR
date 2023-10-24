#!/usr/bin/python3

import sys
sys.path.append("/home/speech/miniconda3/envs/neural-dsp/lib/python3.10/site-packages")

import os
import random
import shutil
import librosa


complete_text_file_path=sys.argv[2]
directory_of_speakers=sys.argv[1]
spkr=sys.argv[3]

with open("./text","a") as text:
     for speaker in os.listdir(directory_of_speakers):
        if len(speaker)<5:
           for wrdlab in os.listdir(directory_of_speakers+"/"+speaker+'/label'):
               if "wrdlab" == wrdlab.split(".")[1]:
                  with open(directory_of_speakers+"/"+speaker+'/label/'+wrdlab) as file:
                       lines=file.readlines()
                       for i in lines:
                           if "SIL" in i:
                              lines.remove(i)
                       string=wrdlab.split(".")[0]+"	" 
                       for j in lines:
                           #print(j,wrdlab)
                           word=j.split(" ")[2]
                           word=word[0:len(word)-1]
                           string+=word+" "
                     
                       text.write(string+"\n")


with open("./text","r") as text:
     all_lines=text.readlines()
     number_of_training_examples=int(0.8*len(all_lines))
     count=0
     random.shuffle(all_lines)
     with open("./data/train/text","a") as t1:
          with open("./data/test/text","a") as t2:
              for i in all_lines:
                  if count<number_of_training_examples:
                     t1.write(i)
                     count+=1
                  else:
                     t2.write(i)
          
with open("./data/train/utt","a") as utt:
     with open("./data/train/text","r") as t1:
          all_lines=t1.readlines()
          for i in all_lines:
              utt.write(i.split("	")[0]+'\n')
              
with open("./data/test/utt","a") as utt:
     with open("./data/test/text","r") as t1:
          all_lines=t1.readlines()
          for i in all_lines:
              utt.write(i.split("	")[0]+'\n')
              
for i in os.listdir(directory_of_speakers):
    if len(i)<5:
       os.mkdir("./wav/train/"+i)
       os.mkdir("./wav/test/"+i)
       
with open("./data/train/utt","r") as utt:
    all_train_files=utt.readlines()
    for i in all_train_files:
        for speaker in os.listdir(directory_of_speakers):
            if len(speaker)<5:
               for wav in os.listdir(directory_of_speakers+"/"+speaker+"/audio"):
                   if i[0:len(i)-1]==wav.split(".")[0]:
                      shutil.copyfile(directory_of_speakers+"/"+speaker+"/audio/"+wav , "./wav/train/"+speaker+'/'+wav)
                     
with open("./data/test/utt","r") as utt:
    all_train_files=utt.readlines()
    for i in all_train_files:
        for speaker in os.listdir(directory_of_speakers):
            if len(speaker)<5:
               for wav in os.listdir(directory_of_speakers+"/"+speaker+"/audio"):
                   if i[0:len(i)-1]==wav.split(".")[0]:
                      shutil.copyfile(directory_of_speakers+"/"+speaker+"/audio/"+wav , "./wav/test/"+speaker+'/'+wav)                           
      
unique_words=[]                       
with open(complete_text_file_path,"r") as comp:
     lines=comp.readlines()
     for i in lines:
         t=i.split(" ")
         for j in t:
            if "\n" in j:
                if j[0:len(j)-1] not in unique_words:
                   unique_words.append(j[0:len(j)-1])
            else:
                if j not in unique_words:
                   unique_words.append(j)
print("Number of unique words: ",len(unique_words))      
      
unique=[]
with open("./data/local/dict/lexicon.txt","a") as lexicon:             
         for wrdlab in os.listdir(directory_of_speakers+"/"+spkr+"/label"):
             if "wrdlab"==wrdlab.split(".")[1]:
                with open(directory_of_speakers+"/"+spkr+"/label/"+wrdlab,"r") as wb:
                     word_sequences=[]
                     phone_sequences=[]
                     all_lines=wb.readlines()
                     for word in all_lines:
                         if "SIL" not in word.split(" ")[2]:
                             word_sequences.append(word.split(" ")[2][0:len(word.split(" ")[2])-1])
                     #print("The word sequences are : ",word_sequences)
                     phone_lab_file=wrdlab.split(".")[0]+".lab"
                     try:
                         with open(directory_of_speakers+"/"+spkr+"/label/"+phone_lab_file,"r") as lab:
                               phone_lines=lab.readlines()
                               sequence=''
                               #print("The phone lines are: ",phone_lines)
                               for j in phone_lines:
                                   phone=j.split(" ")[2]
                                   #phone=phone[0:len(phone)-1]
                                   if phone=="SIL":
                                      if sequence !='':
                                         phone_sequences.append(sequence[0:len(sequence)-1])
                                         sequence=''
                                   else:
                                      sequence+=phone+" "
                         #print("The phone sequences are: ",phone_sequences)
                         #print()
                         #print()
                         for i in range(len(word_sequences)):
                             line=word_sequences[i]+"	"+phone_sequences[i]+"\n"
                             if line not in unique:
                                unique.append(line)
                                lexicon.write(line)
                                   
                     except:
                         with open(directory_of_speakers+"/"+spkr+"/label/"+phone_lab_file,"r") as lab:
                              phone_lines=lab.readlines()
                              sequence=''
                              #print("The phone lines are: ",phone_lines)
                              for j in phone_lines:
                                  phone=j.split(" ")[2]
                                  phone=phone[0:len(phone)-1]
                                  if phone=="SIL":
                                     if sequence !='':
                                        phone_sequences.append(sequence[0:len(sequence)-1])
                                        sequence=''
                                  else:
                                     sequence+=phone+" "
                         #print("The phone sequences are: ",phone_sequences)
                         #print()
                         #print()
                         for i in range(len(word_sequences)):
                             line=word_sequences[i]+"	"+phone_sequences[i]+"\n"
                             if line not in unique:
                                unique.append(line)
                                lexicon.write(line)
         lexicon.write("sil	sil"+"\n")
         lexicon.write("!SIL	sil"+"\n")                

with open("./data/train/wav.scp","a") as scp:
     for speaker in os.listdir("./wav/train"):
         for wav in os.listdir("./wav/train/"+speaker):
             scp.write(wav.split(".")[0]+"	"+"./wav/train/"+speaker+"/"+wav+"\n")

with open("./data/test/wav.scp","a") as scp:
     for speaker in os.listdir("./wav/test"):
         for wav in os.listdir("./wav/test/"+speaker):
             scp.write(wav.split(".")[0]+"      "+"./wav/test/"+speaker+"/"+wav+"\n")
             
with open("./data/local/dict/optional_silence.txt","a") as opt:
     opt.write('sil'+'\n')
    
with open("./data/local/dict/silence_phones.txt","a") as opt:
     opt.write('sil'+'\n')
     
all_phones=[]     
with open("./data/local/dict/nonsilence_phones.txt","a") as ph:
     with open("./data/local/dict/lexicon.txt","r") as p:
          for i in p.readlines():
              #print(i)
              for j in i.split("	")[1].split(" "):
                  #print(j)
                  phone=j
                  if "\n" in j: phone=j[0:len(j)-1]
                  if phone not in all_phones:
                     if phone !="sil":
                        all_phones.append(phone)
          all_phones.sort()
          for i in all_phones:
              ph.write(i+"\n")
         
with open("./data/train/trans","a") as trans:
     with open("./data/train/text","r") as txt:
          f=txt.readlines()
          for i in f:
              trans.write(i.split("	")[1])
              
with open("./data/test/trans","a") as trans:
     with open("./data/test/text","r") as txt:
          f=txt.readlines()
          for i in f:
              trans.write(i.split("	")[1])
              
with open("./data/train/utt2dur","a") as utt2dur:
     for speaker in os.listdir("./wav/train"):
         for wav in os.listdir("./wav/train/"+speaker):
             utt2dur.write(wav.split(".")[0]+" "+str(librosa.get_duration(path='./wav/train/'+speaker+"/"+wav))+"\n")
             

with open("./data/train/trans","r") as f1:
     f=f1.readlines()
with open("./data/train/trans","w") as f2:
     for i in f:    
         f2.write(" "+i)

with open("./data/train/trans","r") as f:
     lines=f.readlines()
with open("./data/train/lm_train.txt","w") as f1:
     for i in lines:
         f1.write("<s>"+i[0:len(i)-1]+"</s>\n") 

