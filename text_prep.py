import os

dir='/home/ananth/Downloads/SSN_TDSC/data/mild/'

spkrs = os.listdir(dir)

for i in spkrs[:]:
    if len(i)>4:
       spkrs.remove(i)

with open('/home/ananth/Downloads/SSN_TDSC/documents/complete_text','r') as r:
     lines = r.readlines()

with open('text','w') as t:
     for spk in spkrs: 
         for wav in os.listdir(dir+spk+'/audio'):
             utt_id = wav.split('.')[0]
             sent_id=int(utt_id[3::])-1
             t.write(utt_id+'\t'+lines[sent_id])
