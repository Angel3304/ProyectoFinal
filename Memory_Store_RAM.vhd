library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Memory_Store_RAM is
  port(
    clk      : in  std_logic;
    we       : in  std_logic;
    Addr_in  : in  std_logic_vector(7 downto 0);
    Data_in  : in  std_logic_vector(23 downto 0);
    Data_out : out std_logic_vector(23 downto 0)
  );
end entity;

architecture Behavioral of Memory_Store_RAM is

  -- Opcodes (Tus instrucciones)
  constant OP_LDX   : std_logic_vector(7 downto 0) := x"01"; 
  constant OP_LDY   : std_logic_vector(7 downto 0) := x"02"; 
  constant OP_ADD   : std_logic_vector(7 downto 0) := x"03";
  constant OP_ADDI  : std_logic_vector(7 downto 0) := x"04";
  constant OP_CMP   : std_logic_vector(7 downto 0) := x"05";
  constant OP_DISP  : std_logic_vector(7 downto 0) := x"06"; -- Muestra X en 7-Seg
  constant OP_JUMP  : std_logic_vector(7 downto 0) := x"07";
  constant OP_BR_NZ : std_logic_vector(7 downto 0) := x"08";
  constant OP_SUB   : std_logic_vector(7 downto 0) := x"09";
  constant OP_WAIT  : std_logic_vector(7 downto 0) := x"0A";
  constant OP_BS    : std_logic_vector(7 downto 0) := x"0B";
  constant OP_BNC   : std_logic_vector(7 downto 0) := x"0C";
  constant OP_BNV   : std_logic_vector(7 downto 0) := x"0D";
  constant OP_MUL   : std_logic_vector(7 downto 0) := x"0E";
  constant OP_STOP  : std_logic_vector(7 downto 0) := x"0F";
  constant OP_DIV   : std_logic_vector(7 downto 0) := x"10";
  constant OP_STX   : std_logic_vector(7 downto 0) := x"11";
  
  -- NUEVAS
  constant OP_LDI   : std_logic_vector(7 downto 0) := x"12";
  constant OP_LDIY  : std_logic_vector(7 downto 0) := x"13";

  type t_mem_array is array (0 to 255) of std_logic_vector(7 downto 0);
  
  signal mem_array : t_mem_array := (
    -- 1. Cargar 1111 en X para saber que arrancamos
    0 => x"12", 1 => x"11", 2 => x"00", -- LDI x11
    3 => x"06", 4 => x"00", 5 => x"00", -- DISP (Deberías ver 0011 brevemente)
    
    -- 2. Leer Teclado (Sobreescribir X)
    6 => x"01", 7 => x"F0", 8 => x"00", -- LDX xF0 (Aquí debería entrar tu HARDCODE x5)
    
    -- 3. Mostrar el nuevo valor
    9 => x"06", 10 => x"00", 11 => x"00", -- DISP (Si Hardcode funciona -> 0005)
    
    -- 4. Loop
    12 => x"07", 13 => x"0C", 14 => x"00", -- Jump a 12 

    others => x"00"
  );

begin
  Data_out <= mem_array(to_integer(unsigned(Addr_in))) & 
              mem_array(to_integer(unsigned(Addr_in)) + 1) & 
              mem_array(to_integer(unsigned(Addr_in)) + 2);

  Write_Process : process(clk)
  begin
    if rising_edge(clk) then
      if we = '1' then
        mem_array(to_integer(unsigned(Addr_in))) <= Data_in(7 downto 0);
      end if;
    end if;
  end process Write_Process;
end architecture;