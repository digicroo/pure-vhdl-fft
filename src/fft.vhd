library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.conv_std_logic_vector;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_misc.all;

-----------------------------------------------------------
-- DIF FFT

entity fft is
    generic(
        DataWidth: integer;
        TwiddleWidth: integer;
        MaxShiftRegDelay: integer := 64;
        FFTlen: integer;
        BitReversedInput: integer
    );
    port(
        clk: in std_logic;
        reset: in std_logic;
        in_data_re: in std_logic_vector(DataWidth-1 downto 0);
        in_data_im: in std_logic_vector(DataWidth-1 downto 0);
        in_data_valid: in std_logic;     -- must be block-wise
        ifft_in: in std_logic;
        scaling_sch: in std_logic_vector(2*integer(ceil(log2(real(FFTlen)/2.0)))-1 downto 0);
        out_data_re: out std_logic_vector(DataWidth-1 downto 0);
        out_data_im: out std_logic_vector(DataWidth-1 downto 0);
        out_data_valid: out std_logic;
        ifft_out: out std_logic;
        cc_err_out: out std_logic
    );
end entity fft;

-----------------------------------------------------------

architecture rtl of fft is

    constant LOGLEN: integer := integer(round(log2(real(FFTlen))));
    constant NUM_R22_STAGES: integer := LOGLEN / 2;
    constant NUM_R2_STAGES: integer := LOGLEN mod 2;    -- insert a radix-2 stage if FFTlen is an odd power of 2
    constant SCALING_LEN: integer := scaling_sch'length;

    type vecvec is array(integer range<>) of std_logic_vector(DataWidth-1 downto 0);
    type scaling_vecvec is array(integer range<>) of std_logic_vector(SCALING_LEN-1 downto 0);
    signal data_vec_re, data_vec_im: vecvec(0 to NUM_R22_STAGES);
    signal valid_vec, ifft_vec: std_logic_vector(0 to NUM_R22_STAGES);
    signal cc_err_vec: std_logic_vector(2*NUM_R22_STAGES downto 0); -- leftmost bit is always zero if FFTlen is an even power of 2
    signal scaling_vec: scaling_vecvec(0 to NUM_R22_STAGES);

    signal dovesochek_in_data_re, dovesochek_in_data_im: std_logic_vector(DataWidth downto 0);
    signal dovesochek_out_data_re, dovesochek_out_data_im: std_logic_vector(DataWidth downto 0);
    signal dovesochek_in_valid, dovesochek_out_valid: std_logic;
    signal dovesochek_in_ifft, dovesochek_out_ifft: std_logic;
    signal dovesochek_in_scaling, dovesochek_out_scaling: std_logic_vector(SCALING_LEN-1 downto 0);

    signal dovesochek_rounder_in_re, dovesochek_rounder_in_im: std_logic_vector(DataWidth+1-1 downto 0);
    signal dovesochek_rounder_in_valid: std_logic;

    signal scaling: std_logic_vector(1 downto 0);
    
begin

    data_vec_re(0) <= in_data_re;
    data_vec_im(0) <= in_data_im;
    valid_vec(0) <= in_data_valid;
    ifft_vec(0) <= ifft_in;
    scaling_vec(0) <= scaling_sch;

    r22_stages_gen:
    for stage in 0 to NUM_R22_STAGES-1 generate
        r22_stage_pair_inst : entity work.r22_stage_pair
        generic map (
            DataWidth        => DataWidth,
            TwiddleWidth     => TwiddleWidth,
            MaxShiftRegDelay => MaxShiftRegDelay,
            FFTlen           => FFTlen,
            StagePairNum     => stage,
            BitReversedInput => BitReversedInput
        )
        port map (
            clk            => clk,
            reset          => reset,
            in_data_re     => data_vec_re(stage),
            in_data_im     => data_vec_im(stage),
            in_data_valid  => valid_vec(stage),
            ifft_in        => ifft_vec(stage),
            scaling_sch_in => scaling_vec(stage),
            out_data_re    => data_vec_re(stage+1),
            out_data_im    => data_vec_im(stage+1),
            out_data_valid => valid_vec(stage+1),
            ifft_out       => ifft_vec(stage+1),
            scaling_sch_out => scaling_vec(stage+1),
            cc_err         => cc_err_vec(2*stage+1 downto 2*stage)
        );        
    end generate;

    no_r2_stage_gen:
    if NUM_R2_STAGES = 0 generate
        out_data_re <= data_vec_re(NUM_R22_STAGES);
        out_data_im <= data_vec_im(NUM_R22_STAGES);
        out_data_valid <= valid_vec(NUM_R22_STAGES);
        ifft_out <= ifft_vec(NUM_R22_STAGES);
    end generate;

    r2_stage_gen:
    if NUM_R2_STAGES > 0 generate
        dovesochek_in_data_re <= std_logic_vector(resize(signed(data_vec_re(NUM_R22_STAGES)), DataWidth+1));
        dovesochek_in_data_im <= std_logic_vector(resize(signed(data_vec_im(NUM_R22_STAGES)), DataWidth+1));
        dovesochek_in_valid <= valid_vec(NUM_R22_STAGES);
        dovesochek_in_ifft <= ifft_vec(NUM_R22_STAGES);
        dovesochek_in_scaling <= scaling_vec(NUM_R22_STAGES);

        dovesochek_stage : entity work.r22_stage_bf1
        generic map (
            DataWidth    => DataWidth+1,
            FFTlen       => FFTlen,
            BitReversedInput => BitReversedInput,
            StagePairNum => NUM_R22_STAGES
        )
        port map (
            clk         => clk,
            reset       => reset,
            in_data_re  => dovesochek_in_data_re,
            in_data_im  => dovesochek_in_data_im,
            in_valid    => dovesochek_in_valid,
            ifft_in     => dovesochek_in_ifft,
            scale_in    => dovesochek_in_scaling,
            out_data_re => dovesochek_out_data_re,
            out_data_im => dovesochek_out_data_im,
            out_valid   => dovesochek_out_valid,
            ifft_out    => dovesochek_out_ifft,
            scale_out   => dovesochek_out_scaling,
            cc_err      => cc_err_vec(cc_err_vec'high)
        );

        --dovesochek_rounder_in_re <= dovesochek_out_data_re when dovesochek_out_ifft = '0' else dovesochek_out_data_re(DataWidth-1 downto 0) & '0';
        --dovesochek_rounder_in_im <= dovesochek_out_data_im when dovesochek_out_ifft = '0' else dovesochek_out_data_im(DataWidth-1 downto 0) & '0';
        scaling <= dovesochek_out_scaling(SCALING_LEN-1 downto SCALING_LEN-2);
        dovesochek_rounder_in_re <= dovesochek_out_data_re(DataWidth-1 downto 0) & '0' when scaling = "00" else dovesochek_out_data_re;
        dovesochek_rounder_in_im <= dovesochek_out_data_im(DataWidth-1 downto 0) & '0' when scaling = "00" else dovesochek_out_data_im;
        dovesochek_rounder_in_valid <= dovesochek_out_valid;

        dovesochek_rounder_re : entity work.rounder_away_opt_cplx
        generic map (
            InWidth  => DataWidth+1,
            OutWidth => DataWidth,
            Mode => "HE"
        )
        port map (
            clk         => clk,
            reset       => reset,
            data_in_re  => dovesochek_rounder_in_re,
            data_in_im  => dovesochek_rounder_in_im,
            valid_in    => dovesochek_rounder_in_valid,
            data_out_re => out_data_re,
            data_out_im => out_data_im,
            valid_out   => out_data_valid
        );
        
        ifft_out <= dovesochek_out_ifft when rising_edge(clk);  --! TODO: put through rounder via user_in/out
    end generate;

    cc_err_out <= or_reduce(cc_err_vec);

end architecture;