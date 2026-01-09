library ieee;
use ieee.std_logic_1164.all;

entity LFSR_8bit is
  port(
    clk    : in  std_logic;
    reset  : in  std_logic; -- Reset asíncrono recomendado
    enable : in  std_logic; -- Este vendría de tu lógica de control/botón
    q      : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of LFSR_8bit is
  -- Semilla inicial (Seed). Evita que sea "00000000" o se quedará trabado.
  signal r : std_logic_vector(7 downto 0) := x"AE";
begin
  process(clk, reset)
  begin
    if reset = '1' then 
      r <= x"AE"; -- Volver a la semilla inicial
    elsif rising_edge(clk) then
      if enable = '1' then
        -- Polinomio para 8 bits: x^8 + x^6 + x^5 + x^4 + 1
        -- Esto asegura un ciclo de máxima longitud (255 estados)
        r <= r(6 downto 0) & (r(7) xor r(5) xor r(4) xor r(3));
      end if;
    end if;
  end process;

  q <= r; -- El número pseudoaleatorio actual
end architecture;