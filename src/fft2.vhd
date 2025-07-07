library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.conv_std_logic_vector;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_misc.all;

-----------------------------------------------------------
-- DIF FFT

entity fft2 is
    generic(
        DataWidth: integer;
        TwiddleWidth: integer;
        MaxShiftRegDelay: integer := 64;
        FFTlen: integer;
        BitReversedInput: integer;
        Nchannels: integer
    );
    port(
        clk: in std_logic;
        reset: in std_logic;
        in_data_re: in std_logic_vector(DataWidth-1 downto 0);
        in_data_im: in std_logic_vector(DataWidth-1 downto 0);
        in_data_valid: in std_logic;     -- must be block-wise
        ifft_in: in std_logic;
        scaling_sch: in std_logic_vector(2*integer(ceil(log2(real(FFTlen))/2.0))-1 downto 0);
        out_data_re: out std_logic_vector(DataWidth-1 downto 0);
        out_data_im: out std_logic_vector(DataWidth-1 downto 0);
        out_data_valid: out std_logic;
        ifft_out: out std_logic;
        cc_err_out: out std_logic
    );
end entity fft2;

-----------------------------------------------------------

architecture rtl of fft2 is

    constant LOGLEN: integer := integer(round(log2(real(FFTlen))));
    constant NUM_R22_STAGES: integer := LOGLEN / 2;
    constant NUM_R2_STAGES: integer := LOGLEN mod 2;    -- insert a radix-2 stage if FFTlen is an odd power of 2
    constant SCALING_LEN: integer := scaling_sch'length;
    constant NUM_STAGES_TOTAL: integer := NUM_R22_STAGES + NUM_R2_STAGES;
    constant EXTRA_BITS_LAST_STAGE: integer := 2;   -- max TwiddleWidth

    type invec is array(integer range<>) of std_logic_vector(DataWidth-1 downto 0);
    type outvec is array(integer range<>) of std_logic_vector(DataWidth+TwiddleWidth-1 downto 0);
    type scaling_vecvec is array(integer range<>) of std_logic_vector(SCALING_LEN-1 downto 0);
    signal idata_vec_re, idata_vec_im: invec(0 to NUM_R22_STAGES);
    signal odata_vec_re, odata_vec_im: outvec(0 to NUM_R22_STAGES);
    signal ivalid_vec, ifft_in_vec: std_logic_vector(0 to NUM_R22_STAGES);
    signal ovalid_vec, ifft_out_vec: std_logic_vector(0 to NUM_R22_STAGES);
    signal cc_err_vec: std_logic_vector(2*NUM_R22_STAGES downto 0) := (others=>'0'); -- leftmost bit is always zero if FFTlen is an even power of 2
    signal scaling_in_vec, scaling_out_vec: scaling_vecvec(0 to NUM_R22_STAGES);

    signal idata_fin_re: std_logic_vector(DataWidth+EXTRA_BITS_LAST_STAGE-1  downto 0);
    signal idata_fin_im: std_logic_vector(DataWidth+EXTRA_BITS_LAST_STAGE-1  downto 0);
    signal ivalid_fin: std_logic;
    signal ifft_in_fin: std_logic;
    signal odata_fin_re, odata_fin_im: std_logic_vector(DataWidth+EXTRA_BITS_LAST_STAGE+2-1  downto 0);
    signal ovalid_fin, ifft_out_fin: std_logic;

    signal dovesochek_in_data_re, dovesochek_in_data_im: std_logic_vector(DataWidth+EXTRA_BITS_LAST_STAGE+1-1 downto 0);
    signal dovesochek_out_data_re, dovesochek_out_data_im: std_logic_vector(DataWidth+EXTRA_BITS_LAST_STAGE+1-1 downto 0);
    signal dovesochek_in_valid, dovesochek_out_valid: std_logic;
    signal dovesochek_in_ifft, dovesochek_out_ifft: std_logic;
    signal dovesochek_in_scaling, dovesochek_out_scaling: std_logic_vector(SCALING_LEN-1 downto 0);
    
    signal dovesochek_rounder_in_re, dovesochek_rounder_in_im: std_logic_vector(DataWidth+EXTRA_BITS_LAST_STAGE+1-1 downto 0);
    signal dovesochek_rounder_in_valid: std_logic;

    signal scaling_in_fin: std_logic_vector(SCALING_LEN-1 downto 0);
    signal scaling: std_logic_vector(1 downto 0);
    
begin

    idata_vec_re(0) <= in_data_re;
    idata_vec_im(0) <= in_data_im;
    ivalid_vec(0) <= in_data_valid;
    ifft_in_vec(0) <= ifft_in;
    scaling_in_vec(0) <= scaling_sch;

    -- generate all r2^2 stages except the last one
    r22_stages_gen:
    for stage in 0 to NUM_STAGES_TOTAL-2 generate
        r22_pair_nonlast : entity work.r22_stage_pair2
        generic map (
            DataWidth        => DataWidth,
            TwiddleWidth     => TwiddleWidth,
            MaxShiftRegDelay => MaxShiftRegDelay,
            FFTlen           => FFTlen,
            StagePairNum     => stage,
            BitReversedInput => BitReversedInput,
            Nchannels        => Nchannels
        )
        port map (
            clk             => clk,
            reset           => reset,
            in_data_re      => idata_vec_re(stage),
            in_data_im      => idata_vec_im(stage),
            in_data_valid   => ivalid_vec(stage),
            ifft_in         => ifft_in_vec(stage),
            scaling_sch_in  => scaling_in_vec(stage),
            out_data_re     => odata_vec_re(stage),
            out_data_im     => odata_vec_im(stage),
            out_data_valid  => ovalid_vec(stage),
            ifft_out        => ifft_out_vec(stage),
            scaling_sch_out => scaling_out_vec(stage),
            cc_err          => cc_err_vec(2*stage+1 downto 2*stage)
        );

        gen_rounder_nonbeforelast: if stage /= NUM_STAGES_TOTAL-2 generate
            rounder_inst : entity work.rounder_away_opt_cplx
            generic map (
                InWidth  => DataWidth + TwiddleWidth,   -- (DataWidth+2) + (TwiddleWidth-2)
                OutWidth => DataWidth,
                Mode => "HE"
            )
            port map (
                clk         => clk,
                reset       => reset,
                data_in_re  => odata_vec_re(stage),
                data_in_im  => odata_vec_im(stage),
                valid_in    => ovalid_vec(stage),
                data_out_re => idata_vec_re(stage+1),
                data_out_im => idata_vec_im(stage+1),
                valid_out   => ivalid_vec(stage+1)
            );

            ifft_in_vec(stage+1) <= ifft_out_vec(stage) when rising_edge(clk);
            scaling_in_vec(stage+1) <= scaling_out_vec(stage) when rising_edge(clk);
        end generate gen_rounder_nonbeforelast;
    end generate r22_stages_gen;

    no_r2_stage_gen:
    if NUM_R2_STAGES = 0 generate
        -- last R22 stage
        idata_fin_re <= odata_vec_re(NUM_STAGES_TOTAL-2)(DataWidth+TwiddleWidth-1 downto TwiddleWidth - EXTRA_BITS_LAST_STAGE);
        idata_fin_im <= odata_vec_im(NUM_STAGES_TOTAL-2)(DataWidth+TwiddleWidth-1 downto TwiddleWidth - EXTRA_BITS_LAST_STAGE);
        ivalid_fin <= ovalid_vec(NUM_STAGES_TOTAL-2);
        ifft_in_fin <= ifft_out_vec(NUM_STAGES_TOTAL-2);
        scaling_in_fin <= scaling_out_vec(NUM_STAGES_TOTAL-2);

        r22_pair_last : entity work.r22_stage_pair2
        generic map (
            DataWidth        => DataWidth + EXTRA_BITS_LAST_STAGE,
            TwiddleWidth     => 2,  -- is added to DataWidth
            MaxShiftRegDelay => MaxShiftRegDelay,
            FFTlen           => FFTlen,
            StagePairNum     => NUM_STAGES_TOTAL-1,
            BitReversedInput => BitReversedInput,
            Nchannels        => Nchannels
        )
        port map (
            clk            => clk,
            reset          => reset,
            in_data_re     => idata_fin_re,
            in_data_im     => idata_fin_im,
            in_data_valid  => ivalid_fin,
            ifft_in        => ifft_in_fin,
            scaling_sch_in => scaling_in_fin,
            out_data_re    => odata_fin_re,
            out_data_im    => odata_fin_im,
            out_data_valid => ovalid_fin,
            ifft_out       => ifft_out_fin,
            scaling_sch_out => open,
            cc_err         => cc_err_vec(2*NUM_STAGES_TOTAL-1 downto 2*NUM_STAGES_TOTAL-2)
        );

        rounder_inst : entity work.rounder_away_opt_cplx
            generic map (
                InWidth  => DataWidth + EXTRA_BITS_LAST_STAGE + 2,
                OutWidth => DataWidth,
                Mode => "HE"
            )
            port map (
                clk         => clk,
                reset       => reset,
                data_in_re  => odata_fin_re,
                data_in_im  => odata_fin_im,
                valid_in    => ovalid_fin,
                data_out_re => out_data_re,
                data_out_im => out_data_im,
                valid_out   => out_data_valid
            );

        ifft_out <= ifft_out_fin when rising_edge(clk);
    end generate;

    r2_stage_gen:
    if NUM_R2_STAGES > 0 generate
        dovesochek_in_data_re <= 
            odata_vec_re(NUM_STAGES_TOTAL-2)(DataWidth+TwiddleWidth-1) &    -- sign bit extension
            odata_vec_re(NUM_STAGES_TOTAL-2)(DataWidth+TwiddleWidth-1 downto TwiddleWidth - EXTRA_BITS_LAST_STAGE);
        dovesochek_in_data_im <=
            odata_vec_im(NUM_STAGES_TOTAL-2)(DataWidth+TwiddleWidth-1) &    -- sign bit extension
            odata_vec_im(NUM_STAGES_TOTAL-2)(DataWidth+TwiddleWidth-1 downto TwiddleWidth - EXTRA_BITS_LAST_STAGE);
        dovesochek_in_valid <= ovalid_vec(NUM_STAGES_TOTAL-2);
        dovesochek_in_ifft <= ifft_out_vec(NUM_STAGES_TOTAL-2);
        dovesochek_in_scaling <= scaling_out_vec(NUM_STAGES_TOTAL-2);

        dovesochek_stage : entity work.r22_stage_bf1
        generic map (
            DataWidth        => DataWidth+EXTRA_BITS_LAST_STAGE+1,
            FFTlen           => FFTlen,
            BitReversedInput => BitReversedInput,
            Nchannels        => Nchannels,
            StagePairNum     => NUM_R22_STAGES
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
        
        scaling <= dovesochek_out_scaling(SCALING_LEN-1 downto SCALING_LEN-2);
        --dovesochek_rounder_in_re <= dovesochek_out_data_re when dovesochek_out_ifft = '0' else dovesochek_out_data_re(DataWidth+EXTRA_BITS_LAST_STAGE-1 downto 0) & '0';
        --dovesochek_rounder_in_im <= dovesochek_out_data_im when dovesochek_out_ifft = '0' else dovesochek_out_data_im(DataWidth+EXTRA_BITS_LAST_STAGE-1 downto 0) & '0';

        -- Scaling for the last stage can be only 00 or 01 when FFTlen is an odd power of 2. Values 10 and 11 are treated as 01.
        dovesochek_rounder_in_re <= dovesochek_out_data_re(DataWidth+EXTRA_BITS_LAST_STAGE-1 downto 0) & '0' when scaling = "00" else dovesochek_out_data_re;
        dovesochek_rounder_in_im <= dovesochek_out_data_im(DataWidth+EXTRA_BITS_LAST_STAGE-1 downto 0) & '0' when scaling = "00" else dovesochek_out_data_im;
        --dovesochek_rounder_in_re <= dovesochek_out_data_re(DataWidth-1 downto 0) & '0' when scaling = "00" else dovesochek_out_data_re;
        --dovesochek_rounder_in_im <= dovesochek_out_data_im(DataWidth-1 downto 0) & '0' when scaling = "00" else dovesochek_out_data_im;
        dovesochek_rounder_in_valid <= dovesochek_out_valid;

        dovesochek_rounder : entity work.rounder_away_opt_cplx
        generic map (
            InWidth => DataWidth+EXTRA_BITS_LAST_STAGE+1,
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