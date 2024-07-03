import subprocess

with open('Tamizh-map','r') as m:
     lines = m.readlines()
     
d = {}

for line in lines:
       t,a = line.split()
       d[t]=a
    
    
with open('unique_Tamizh_words','r') as u:
    lines = u.readlines()
    

with open('lexicon.txt','w') as l:   
	for word in lines:
	    lis=[]
	    
	    check_f = 0
	    if 'ஃ' in word:
	        word = word.replace('ஃப','f')
	        check_f = 1
	    
	    for ch in word:
	      if ch=='V':
	         if lis[-1] not in ['a','aa','i','ii','u','uu','e','ee','ai','o','oo','au']:
	            lis[-1]=lis[-1].replace('t','d')
	            lis[-1]=lis[-1].replace('p','b')
	            lis[-1]=lis[-1].replace('k','g')
	         else:
	            lis[-2]=lis[-2].replace('t','d')
	            lis[-2]=lis[-2].replace('p','b')
	            lis[-2]=lis[-2].replace('k','g')	         
	            
 
	            
	      try:
	        lis.append(d[ch])
	      except:
	        # to handle '்' case
	        pass 
	    
	    tran=''
	    length=len(lis)
	    i=0
	    
	   
	    
	    while i<length:
                  try:
 
                        
                     if lis[i+1] in [ 'a','aa','i','ii','u','uu','e','ee','ai','o','oo','au']:
                        l.write(lis[i]+' '+lis[i+1]+' ') 
                        tran+=lis[i]+lis[i+1]
                        i+=2
                        
                     elif lis[i+1] in ['dot']:
                       
                        l.write(lis[i]+' ')
                        tran+=lis[i]
                        i+=2
                                                
                        

                     else:
                        if lis[i] not in [ 'a','aa','i','ii','u','uu','e','ee','ai','o','oo','au']:
                           l.write(lis[i]+' '+'a'+' ')
                           tran+=lis[i]+'a'
                           
                        else:
                           l.write(lis[i]+' ')
                           tran+=lis[i]
                        i+=1   
                  except:
                        l.write(lis[i]+' '+'a'+' ')
                        tran+=lis[i]+'a'
                        i+=1
	    l.write('\t'+tran)
	    l.write('\n')
	    
subprocess.run("awk -F'\t' '{print $2 \"\t\" $1}' lexicon.txt > temp.txt && mv temp.txt lexicon.txt", shell=True)	    		

subprocess.run("""
sed -i -e 's/u\t/eu\t/g' \
-e 's/uk/euk/g' \
-e 's/u k/eu k/g' \
-e 's/up\t/eup\t/g' \
-e 's/u p \\n/eu p \\n/g' \
-e 's/ut\t/eut\t/g' \
-e 's/u t \\n/eu t \\n/g' lexicon.txt
""", shell=True)

subprocess.run("sed ':a;N;$!ba;s/u \\n/eu \\n/g' lexicon.txt > temp.txt", shell=True)
subprocess.run("sed ':a;N;$!ba;s/\\nc/\\ns/g' temp.txt > lexicon.txt", shell=True)

