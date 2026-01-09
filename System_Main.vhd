library ieee;
use ieee.std_logic_1164.all;

entity System_Main is
  port (
    -- Entradas de Sistema
    clk_in      : in  std_logic;
    sys_reset   : in  std_logic; -- Reset físico (botón)
    sys_run     : in  std_logic; -- Botón de Run/Pause
    
    -- Switches (Aun se usan para eq_select interno)
    i_eq_select : in  std_logic_vector(1 downto 0);
    
    -- === TECLADO MATRICIAL ===
    KEYPAD_ROW  : in  std_logic_vector(3 downto 0); -- Filas (Entradas con Pull-up)
    KEYPAD_COL  : out std_logic_vector(3 downto 0); -- Columnas (Salidas de barrido)
    
    -- === MATRIZ LED RGB ===
    RGB_ROW     : out std_logic_vector(7 downto 0); -- Cátodos/Ánodos comunes de fila
    RGB_R       : out std_logic_vector(7 downto 0); -- Canales Rojo
    RGB_G       : out std_logic_vector(7 downto 0); -- Canales Verde
    RGB_B       : out std_logic_vector(7 downto 0); -- Canales Azul
    
    -- === SALIDAS DE DEBUG/ESTADO ===
    LEDS        : out std_logic_vector(4 downto 0); -- Muestra valor de x"E0"
    LEDS_FLAGS  : out std_logic_vector(3 downto 0); -- Muestra Banderas [Z, S, C, OV]

    -- === DISPLAY 7 SEGMENTOS ===
    SEG_A  : out std_logic;  SEG_B  : out std_logic;  SEG_C  : out std_logic;
    SEG_D  : out std_logic;  SEG_E  : out std_logic;  SEG_F  : out std_logic;
    SEG_G  : out std_logic;  SEG_DP : out std_logic;
    DIG1   : out std_logic;  DIG2   : out std_logic;
    DIG3   : out std_logic;  DIG4   : out std_logic
  );
end entity System_Main;

architecture Behavioral of System_Main is

  -- 1. COMPONENTE: CPU (La versión modificada que te di antes)
  component Processor_Unit is
    port (
      master_clk      : in  std_logic;
      master_reset    : in  std_logic;
      master_run      : in  std_logic;
      eq_select_in    : in  std_logic_vector(1 downto 0);
      
      -- Nuevos puertos de Periféricos
      i_key_code      : in  std_logic_vector(3 downto 0);
      i_key_valid     : in  std_logic;
      o_video_cmd     : out std_logic_vector(7 downto 0);
      
      -- Salidas estándar
      leds_out        : out std_logic_vector(4 downto 0);
      o_flags         : out std_logic_vector(3 downto 0);
      o_seg_a         : out std_logic; o_seg_b : out std_logic; o_seg_c : out std_logic;
      o_seg_d         : out std_logic; o_seg_e : out std_logic; o_seg_f : out std_logic;
      o_seg_g         : out std_logic; o_seg_dp: out std_logic;
      o_dig1          : out std_logic; o_dig2 : out std_logic;
      o_dig3          : out std_logic; o_dig4 : out std_logic
    );
  end component;

  -- 2. COMPONENTE: CONTROLADOR DE TECLADO (Basado en el PDF [cite: 214-225])
  component Keypad_Scanner is
    Port (
      clk       : in  std_logic;
      reset     : in  std_logic;
      rows      : out std_logic_vector(3 downto 0); -- OJO: Tu archivo dice OUT
      cols      : in  std_logic_vector(3 downto 0); -- OJO: Tu archivo dice IN
      key_code  : out std_logic_vector(3 downto 0);
      key_valid : out std_logic
    );
  end component;

  -- 3. COMPONENTE: DRIVER VIDEO SIMPLIFICADO (El que creamos en el paso anterior)
  component Matrix_Controller is
    Port (
        clk       : in  std_logic;
        reset     : in  std_logic; 
        video_cmd : in  std_logic_vector(7 downto 0); 
        row       : out std_logic_vector(7 downto 0); 
        r         : out std_logic_vector(0 to 7); 
        g         : out std_logic_vector(0 to 7); 
        b         : out std_logic_vector(0 to 7)
    );
  end component;

  -- SEÑALES INTERNAS
  signal s_video_command : std_logic_vector(7 downto 0);
  signal s_key_code      : std_logic_vector(3 downto 0);
  signal s_key_valid     : std_logic;
  
  -- Señal dummy para puntos (ya que los muestra el 7 segmentos)
  signal s_puntos_dummy  : std_logic_vector(7 downto 0) := (others => '0');

begin

  -- ==========================================================
  -- INSTANCIA: CPU
  -- ==========================================================
  CPU_Inst : Processor_Unit
    port map (
      master_clk    => clk_in,
      master_reset  => sys_reset,
      master_run    => sys_run,
      eq_select_in  => i_eq_select,
      
      -- Conexión al Bus de Video (Salida)
      o_video_cmd   => s_video_command,
      
      -- Conexión al Bus de Teclado (Entrada)
      i_key_code    => s_key_code,
      i_key_valid   => s_key_valid,
      
      -- Salidas Físicas directas
      leds_out      => LEDS,
      o_flags       => LEDS_FLAGS,
      
      -- Conexión Display 7 Segmentos
      o_seg_a => SEG_A, o_seg_b => SEG_B, o_seg_c => SEG_C,
      o_seg_d => SEG_D, o_seg_e => SEG_E, o_seg_f => SEG_F,
      o_seg_g => SEG_G, o_seg_dp => SEG_DP,
      o_dig1 => DIG1, o_dig2 => DIG2, o_dig3 => DIG3, o_dig4 => DIG4
    );

  -- ==========================================================
  -- INSTANCIA: TECLADO (Hardware Driver)
  -- ==========================================================
  Keypad_Inst : Keypad_Scanner -- Cambio de nombre de instancia
    port map (
      clk       => clk_in,
      reset     => sys_reset,
      rows      => KEYPAD_COL, -- CUIDADO: En tu scanner rows son OUT (barrido)
      cols      => KEYPAD_ROW, -- y cols son IN (lectura)
      key_code  => s_key_code,
      key_valid => s_key_valid
    );

  -- ==========================================================
  -- INSTANCIA: VIDEO (Matriz RGB)
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

end architecture Behavioral;