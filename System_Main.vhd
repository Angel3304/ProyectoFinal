library ieee;
use ieee.std_logic_1164.all;

entity System_Main is
  port (
    -- Entradas de Sistema
    clk_in      : in  std_logic;
    sys_reset   : in  std_logic; -- Reset físico (Botón)
	 sys_run_btn : in  STD_LOGIC;
    
    -- === TECLADO MATRICIAL ===
    -- NOTA: KEYPAD_ROW son las ENTRADAS (Deben llevar Pull-Up en Pin Planner)
    KEYPAD_ROW  : out  std_logic_vector(3 downto 0); 
    -- NOTA: KEYPAD_COL son las SALIDAS (Barrido)
    KEYPAD_COL  : in std_logic_vector(3 downto 0); 
    
    -- === MATRIZ LED RGB ===
    RGB_ROW     : out std_logic_vector(7 downto 0); -- Filas
    RGB_R       : out std_logic_vector(7 downto 0); -- Rojo
    RGB_G       : out std_logic_vector(7 downto 0); -- Verde
    RGB_B       : out std_logic_vector(7 downto 0); -- Azul
    
    -- === SALIDAS DE DEBUG/ESTADO ===
    LEDS_FLAGS  : out std_logic_vector(3 downto 0); -- Banderas

    -- === DISPLAY 7 SEGMENTOS ===
    SEG_A, SEG_B, SEG_C, SEG_D, SEG_E, SEG_F, SEG_G, SEG_DP : out std_logic;
    DIG1, DIG2, DIG3, DIG4 : out std_logic
  );
end entity System_Main;

architecture Behavioral of System_Main is

  -- COMPONENTE: CPU
  component Processor_Unit is
    port (
      master_clk      : in  std_logic;
      master_reset    : in  std_logic;
      master_run      : in  std_logic; -- '1' = Pausa, '0' = Run
      
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

  -- COMPONENTE: TECLADO (Keypad_Scanner)
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

  -- COMPONENTE: VIDEO (Matrix_Controller)
  component Matrix_Controller is
    Port (
        clk       : in  std_logic;
        reset     : in  std_logic; 
        video_cmd : in  std_logic_vector(7 downto 0); 
        row       : out std_logic_vector(7 downto 0); 
        r, g, b   : out std_logic_vector(0 to 7)
    );
  end component;

  -- SEÑALES INTERNAS
  signal s_video_command : std_logic_vector(7 downto 0);
  signal s_key_code      : std_logic_vector(3 downto 0);
  signal s_key_valid     : std_logic;

begin

  -- ==========================================================
  -- INSTANCIA: CPU
  -- ==========================================================
  CPU_Inst : Processor_Unit
    port map (
      master_clk    => clk_in,
      master_reset  => sys_reset,
      -- FIX: Forzamos a '0' para que la CPU corra siempre (Si tu botón es Active Low)
      -- O si tu logica interna es '1'=Pausa, '0'=Run, poner '0' asegura que corra.
      master_run    => sys_run_btn, 
      
      -- Periféricos
      o_video_cmd   => s_video_command,
      i_key_code    => s_key_code,
      i_key_valid   => s_key_valid,
      
      -- Salidas Físicas
      o_flags       => open,
      
      -- Display
      o_seg_a => SEG_A, o_seg_b => SEG_B, o_seg_c => SEG_C, o_seg_d => SEG_D, 
      o_seg_e => SEG_E, o_seg_f => SEG_F, o_seg_g => SEG_G, o_seg_dp => SEG_DP,
      o_dig1 => DIG1, o_dig2 => DIG2, o_dig3 => DIG3, o_dig4 => DIG4
    );

  -- ==========================================================
  -- INSTANCIA: TECLADO
  -- ==========================================================
  Keypad_Inst : Keypad_Scanner 
    port map (
      clk       => clk_in,
      reset     => sys_reset,
      -- CUIDADO: Keypad_Scanner.rows (OUT) va a KEYPAD_COL (OUT físico)
      rows      => KEYPAD_ROW, 
      -- CUIDADO: Keypad_Scanner.cols (IN) va a KEYPAD_ROW (IN físico)
      cols      => KEYPAD_COL, 
      key_code  => s_key_code,
      key_valid => s_key_valid
    );

  -- ==========================================================
  -- INSTANCIA: VIDEO
  -- ==========================================================
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
-- ==========================================
    -- DEBUG: Ver código de tecla en los LEDs físicos
    -- ==========================================
    -- Si key_valid es '1', mostramos el código. Si no, apagamos (o mostramos 'F').
    LEDS_FLAGS <= s_key_code when s_key_valid = '1' else "0000";
end architecture Behavioral;