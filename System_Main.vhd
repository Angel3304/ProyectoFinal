library ieee;
use ieee.std_logic_1164.all;

entity System_Main is
  port (
    -- Entradas de Sistema
    clk_in      : in  std_logic;
    sys_reset   : in  std_logic; 
    sys_run_btn : in  STD_LOGIC;
    
    -- Teclado Matricial
    KEYPAD_ROW  : out std_logic_vector(3 downto 0); 
    KEYPAD_COL  : in  std_logic_vector(3 downto 0); 
    
    -- Matriz LED RGB
    RGB_ROW     : out std_logic_vector(7 downto 0); 
    RGB_R       : out std_logic_vector(7 downto 0); 
    RGB_G       : out std_logic_vector(7 downto 0); 
    RGB_B       : out std_logic_vector(7 downto 0); 
    
    -- Salidas de Estado
    LEDS_FLAGS  : out std_logic_vector(3 downto 0); 

    -- Display 7 Segmentos
    SEG_A, SEG_B, SEG_C, SEG_D, SEG_E, SEG_F, SEG_G, SEG_DP : out std_logic;
    DIG1, DIG2, DIG3, DIG4 : out std_logic
  );
end entity System_Main;

architecture Behavioral of System_Main is

  component Processor_Unit is
    port (
      master_clk      : in  std_logic;
      master_reset    : in  std_logic;
      master_run      : in  std_logic;
      
      -- Periféricos
      i_key_code      : in  std_logic_vector(3 downto 0);
      i_key_valid     : in  std_logic;
      o_video_cmd     : out std_logic_vector(7 downto 0);
      
      -- Salidas
      o_flags         : out std_logic_vector(3 downto 0);
      o_seg_a, o_seg_b, o_seg_c, o_seg_d, o_seg_e, o_seg_f, o_seg_g, o_seg_dp : out std_logic;
      o_dig1, o_dig2, o_dig3, o_dig4 : out std_logic
    );
  end component;

  component Keypad_Scanner is
    Port (
      clk       : in  std_logic;
      reset     : in  std_logic;
      rows      : out std_logic_vector(3 downto 0); 
      cols      : in  std_logic_vector(3 downto 0); 
      key_code  : out std_logic_vector(3 downto 0);
      key_valid : out std_logic
    );
  end component;

  component Matrix_Controller is
    Port (
        clk       : in  std_logic;
        reset     : in  std_logic; 
        video_cmd : in  std_logic_vector(7 downto 0); 
        row       : out std_logic_vector(7 downto 0); 
        r, g, b   : out std_logic_vector(0 to 7)
    );
  end component;

  signal s_video_command : std_logic_vector(7 downto 0);
  signal s_key_code      : std_logic_vector(3 downto 0);
  signal s_key_valid     : std_logic;

begin

  -- Instancia: CPU
  CPU_Inst : Processor_Unit
    port map (
      master_clk    => clk_in,
      master_reset  => sys_reset,
      master_run    => sys_run_btn, 
      o_video_cmd   => s_video_command,
      i_key_code    => s_key_code,
      i_key_valid   => s_key_valid,
      o_flags       => open,
      o_seg_a => SEG_A, o_seg_b => SEG_B, o_seg_c => SEG_C, o_seg_d => SEG_D, 
      o_seg_e => SEG_E, o_seg_f => SEG_F, o_seg_g => SEG_G, o_seg_dp => SEG_DP,
      o_dig1 => DIG1, o_dig2 => DIG2, o_dig3 => DIG3, o_dig4 => DIG4
    );

  -- Instancia: Teclado
  Keypad_Inst : Keypad_Scanner 
    port map (
      clk       => clk_in,
      reset     => sys_reset,
      rows      => KEYPAD_ROW, 
      cols      => KEYPAD_COL, 
      key_code  => s_key_code,
      key_valid => s_key_valid
    );

  -- Instancia: Video
  Video_Inst : Matrix_Controller
    port map (
      clk       => clk_in,
      reset     => sys_reset,
      video_cmd => s_video_command,
      row       => RGB_ROW,
      r         => RGB_R,
      g         => RGB_G,
      b         => RGB_B
    );

  -- Debug LEDs
  LEDS_FLAGS <= s_key_code when s_key_valid = '1' else "0000";

end architecture Behavioral;