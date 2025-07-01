onerror { resume }
transcript off
add wave -noreg -logic {/TB_fft/clk}
add wave -noreg -logic {/TB_fft/reset}
add wave -noreg -logic {/TB_fft/ifft_in}
add wave -noreg -hexadecimal -literal {/TB_fft/in_data_re}
add wave -noreg -hexadecimal -literal {/TB_fft/in_data_im}
add wave -noreg -logic {/TB_fft/in_data_valid}
add wave -noreg -logic {/TB_fft/ifft_out}
add wave -noreg -logic {/TB_fft/out_data_valid}
add wave -noreg -decimal -literal -signed2 {/TB_fft/out_data_re}
add wave -noreg -decimal -literal -signed2 {/TB_fft/out_data_im}
add wave -noreg -hexadecimal -literal {/TB_fft/out_re_d}
add wave -noreg -hexadecimal -literal {/TB_fft/out_im_d}
add wave -noreg -logic {/TB_fft/out_valid_d}
add wave -noreg -height 30 -analog -analogmin -5 -analogmax 5 {/TB_fft/fft_check_proc/fft_diff_re}
add wave -noreg -height 30 -analog -analogmin -5 -analogmax 5 {/TB_fft/fft_check_proc/fft_diff_im}
add wave -noreg -literal {/TB_fft/fft_check_proc/fft_tru_re}
add wave -noreg -literal {/TB_fft/fft_check_proc/fft_tru_im}
add wave -noreg -literal {/TB_fft/fft_check_proc/max_max_err}
add wave -noreg -literal {/TB_fft/fft_check_proc/cur_max_err}
add wave -noreg -literal {/TB_fft/fft_check_proc/mean_mean_err_re}
add wave -noreg -literal {/TB_fft/fft_check_proc/mean_mean_err_im}
add wave -noreg -literal {/TB_fft/fft_check_proc/cur_mean_err_re}
add wave -noreg -literal {/TB_fft/fft_check_proc/cur_mean_err_im}
add wave -noreg -literal {/TB_fft/fft_check_proc/cur_std_err}
add wave -named_row "-- pair0"
add wave -noreg -hexadecimal -literal {/TB_fft/UUT/r22_stages_gen__0/r22_pair_nonlast/in_data_re}
add wave -noreg -hexadecimal -literal {/TB_fft/UUT/r22_stages_gen__0/r22_pair_nonlast/in_data_im}
add wave -noreg -logic {/TB_fft/UUT/r22_stages_gen__0/r22_pair_nonlast/in_data_valid}
add wave -noreg -logic {/TB_fft/UUT/r22_stages_gen__0/r22_pair_nonlast/ifft_in}
add wave -noreg -hexadecimal -literal {/TB_fft/UUT/r22_stages_gen__0/r22_pair_nonlast/out_data_re}
add wave -noreg -hexadecimal -literal {/TB_fft/UUT/r22_stages_gen__0/r22_pair_nonlast/out_data_im}
add wave -noreg -logic {/TB_fft/UUT/r22_stages_gen__0/r22_pair_nonlast/out_data_valid}
add wave -noreg -logic {/TB_fft/UUT/r22_stages_gen__0/r22_pair_nonlast/ifft_out}
add wave -noreg -hexadecimal -literal {/TB_fft/UUT/r22_stages_gen__0/r22_pair_nonlast/cc_err}
add wave -noreg -logic {/TB_fft/UUT/r22_stages_gen__0/r22_pair_nonlast/ovf_re}
add wave -noreg -logic {/TB_fft/UUT/r22_stages_gen__0/r22_pair_nonlast/ovf_im}
add wave -noreg -logic {/TB_fft/UUT/r22_stages_gen__0/r22_pair_nonlast/ovf}
add wave -named_row "--2l"
add wave -noreg -logic {/TB_fft/UUT/r22_stages_gen__1/r22_pair_nonlast/ovf}
add wave -named_row "-- last"
cursor "Cursor 1" 23706537ps  
transcript on
