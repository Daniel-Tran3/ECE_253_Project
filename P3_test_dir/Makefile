iveri:
	iverilog -o compiled -c filelist

irun: compiled
	vvp compiled | tee tb_out.txt | less
