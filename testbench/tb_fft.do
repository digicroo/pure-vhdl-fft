onerror { resume }
transcript off
add wave -noreg -logic {/TB_fft/clk}
add wave -noreg -logic {/TB_fft/reset}
add wave -noreg -logic {/TB_fft/ifft_in}
add wave -noreg -binary -literal {/TB_fft/scaling_sch}
add wave -noreg -decimal -literal -signed2 {/TB_fft/in_data_re}
add wave -noreg -decimal -literal -signed2 {/TB_fft/in_data_im}
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
add wave -noreg -literal -signed2 {/TB_fft/fft_check_proc/cur_max_err}
add wave -noreg -literal {/TB_fft/fft_check_proc/mean_mean_err_re}
add wave -noreg -literal {/TB_fft/fft_check_proc/mean_mean_err_im}
add wave -noreg -literal -signed2 {/TB_fft/fft_check_proc/cur_mean_err_re}
add wave -noreg -literal {/TB_fft/fft_check_proc/cur_mean_err_im}
add wave -noreg -literal -signed2 {/TB_fft/fft_check_proc/cur_std_err}
add wave -named_row "-- pair0"
add wave -named_row "--2l"
add wave -named_row "-- last"
add wave -noreg -decimal -literal -signed2 {/TB_fft/fft_check_proc/fft_ix}
add wave -named_row "---"
add wave -noreg -hexadecimal -literal {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_1st_half/cc}
add wave -noreg -hexadecimal -literal -signed2 {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_1st_half/ch_cnt}
add wave -noreg -hexadecimal -literal -signed2 {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_1st_half/vc}
add wave -noreg -logic {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_1st_half/out_valid_i}
add wave -noreg -hexadecimal -literal -signed2 {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_1st_half/vc_ch_cnt}
add wave -noreg -decimal -literal -signed2 {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_1st_half/out_data_re}
add wave -noreg -decimal -literal -signed2 {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_1st_half/out_data_im}
add wave -noreg -logic {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_1st_half/BF/mode}
add wave -noreg -decimal -literal -signed2 {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_1st_half/BF/in_up_re}
add wave -noreg -decimal -literal -signed2 {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_1st_half/BF/in_lo_re}
add wave -noreg -hexadecimal -literal {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_1st_half/delay_line/in_data}
add wave -named_row "---"
add wave -noreg -hexadecimal -literal {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_2nd_half/ispl_cnt}
add wave -noreg -hexadecimal -literal -signed2 {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_2nd_half/ospl_cnt}
add wave -noreg -hexadecimal -literal -signed2 {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_2nd_half/cc}
add wave -noreg -hexadecimal -literal {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_2nd_half/ch_cnt}
add wave -noreg -hexadecimal -literal {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_2nd_half/vc_ch_cnt}
add wave -noreg -logic -signed2 {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_2nd_half/out_valid_i}
add wave -noreg -decimal -literal -signed2 {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_2nd_half/out_data_re}
add wave -noreg -decimal -literal -signed2 {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_2nd_half/out_data_im}
add wave -named_row "--- 2nd stage"
add wave -noreg -logic {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_2nd_half/in_valid}
add wave -noreg -decimal -literal -signed2 {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_2nd_half/in_data_re}
add wave -noreg -decimal -literal -signed2 {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_2nd_half/in_data_im}
add wave -noreg -logic -signed2 {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_2nd_half/out_valid_i}
add wave -noreg -decimal -literal -signed2 {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_2nd_half/out_data_re}
add wave -noreg -decimal -literal -signed2 {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_2nd_half/out_data_im}
add wave -noreg -hexadecimal -literal {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_2nd_half/mode}
add wave -noreg -decimal -literal -signed2 {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_2nd_half/BF/in_up_re}
add wave -noreg -decimal -literal -signed2 {/TB_fft/UUT/r22_stages_gen__0/r22_stage_pair_inst/r22_stage_2nd_half/BF/in_lo_re}
cursor "Cursor 1" 3.15us  
transcript on
