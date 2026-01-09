library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Memory_Store_ROM is
  port(
    Addr_in  : in  std_logic_vector(7 downto 0);
    Data_bus : out std_logic_vector(23 downto 0)
  );
end entity;

architecture Behavioral of Memory_Store_ROM is -- Nombre corregido
  -- Opcodes
  constant OP_LDX   : std_logic_vector(7 downto 0) := x"01";
  constant OP_LDY   : std_logic_vector(7 downto 0) := x"02";
  constant OP_DISP  : std_logic_vector(7 downto 0) := x"06";
  constant OP_WAIT  : std_logic_vector(7 downto 0) := x"0A";
  constant OP_DIV   : std_logic_vector(7 downto 0) := x"10"; -- Opcode para tu divisor
  constant OP_STORE : std_logic_vector(7 downto 0) := x"11"; -- Opcode para guardar
  constant OP_JUMP  : std_logic_vector(7 downto 0) := x"07";
  constant OP_ADDI  : std_logic_vector(7 downto 0) := x"04";

  -- Direcciones MMIO
  constant ADDR_LFSR : std_logic_vector(7 downto 0) := x"E1";
  constant ADDR_LEDS : std_logic_vector(7 downto 0) := x"E0";

  type t_mem_array is array (0 to 255) of std_logic_vector(23 downto 0);
  
  constant Program_Data : t_mem_array := (
    ------------------------------------------------------------------
    -- Programa: Ruleta Aleatoria
    ------------------------------------------------------------------
	-- Ejemplo de cómo debería verse tu ROM para que el dato pase al buffer
	 
	 0  => OP_WAIT  & x"00"     & x"00", -- Espera a que presiones el botón "Run"
    1  => OP_LDX   & ADDR_LFSR & x"00", -- Captura el valor actual del LFSR
    2  => OP_LDY   & x"25"     & x"00", -- Carga el divisor 37 
    3  => OP_DIV   & x"00"     & x"00", -- Calcula reg_X mod reg_Y (Resultado 0-36 en reg_X)
    4  => OP_DISP  & x"00"     & x"00", -- Pasa el dato al buffer
    5  => OP_JUMP  & x"00"     & x"00", -- Salta de regreso al inicio (dirección 0) para otra jugada
    
    others => (others => '0')
  );
begin
  Data_bus <= Program_Data(to_integer(unsigned(Addr_in)));
end architecture;