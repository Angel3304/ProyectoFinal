library ieee;
use ieee.std_logic_1164.all;

entity System_Main_TB is
end entity;

architecture Behavioral of System_Main_TB is

  -- Periodo de reloj (50 MHz)
  constant CLK_PERIOD : time := 20 ns;

  -- DUT
  component System_Main is
    port (
      clk_in      : in  std_logic;
      sys_reset   : in  std_logic;
      sys_run     : in  std_logic;
      i_eq_select : in  std_logic_vector(1 downto 0);
      SEG_A       : out std_logic;
      SEG_B       : out std_logic;
      SEG_C       : out std_logic;
      SEG_D       : out std_logic;
      SEG_E       : out std_logic;
      SEG_F       : out std_logic;
      SEG_G       : out std_logic;
      SEG_DP      : out std_logic;
      DIG1        : out std_logic;
      DIG2        : out std_logic;
      DIG3        : out std_logic;
      DIG4        : out std_logic
    );
  end component;

  -- Señales
  signal s_clk       : std_logic := '0';
  signal s_reset     : std_logic := '1';
  signal s_run       : std_logic := '0';
  signal s_eq_select : std_logic_vector(1 downto 0) := "00";


begin

  -- ==============================
  -- DUT
  -- ==============================
  UUT : System_Main
    port map (
      clk_in      => s_clk,
      sys_reset   => s_reset,
      sys_run     => s_run,
      i_eq_select => s_eq_select
    );

  -- ==============================
  -- Clock
  -- ==============================
  clk_process : process
  begin
    s_clk <= '0';
    wait for CLK_PERIOD / 2;
    s_clk <= '1';
    wait for CLK_PERIOD / 2;
  end process;

  -- ==============================
  -- Stimulus
  -- ==============================
  stimulus_process : process
  begin
    -- RESET
    s_reset <= '0';
    wait for 100 ns;
    s_reset <= '1';

    -- Esperar unos ciclos
    wait for 200 ns;

    -- Simular botón de ruleta
    s_run <= '1';
    wait for 40 ns;  -- Pulso de botón
    s_run <= '0';

    -- Dejar correr el sistema
    wait for 5 ms;

    -- Segundo disparo
    s_run <= '1';
    wait for 40 ns;
    s_run <= '0';

    wait for 5 ms;

    -- Fin de simulación
    wait;
  end process;

end architecture Behavioral;
