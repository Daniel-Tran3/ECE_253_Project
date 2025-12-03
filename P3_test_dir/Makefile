iveri:
	iverilog -o compiled -c filelist

irun-page: compiled
	vvp compiled | tee tb_out.txt | less

irun: compiled
	vvp compiled | tee tb_out.txt
