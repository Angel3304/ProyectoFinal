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
    -- ============================================================
    -- PROGRAMA DE DIAGNÓSTICO DE TECLADO
    -- ============================================================
    
    -- 0: Inicializar Y en 0 (Para asegurar que la comparación funcione)
    

    -- 3: Inicializar Pantalla (Menú / A Roja)
    0 => OP_LDX,  1 => x"F0", 2 => x"00",  -- Leer Teclado a X
    3 => OP_DISP, 4 => x"00", 5 => x"00",  -- Mostrar X en 7-Seg
    6 => OP_JUMP, 7 => x"00", 8 => x"00",  -- Volver a 0

    -- ================= BUCLE DE LECTURA =================
    -- 9: Leer Teclado (xF0) y guardar en X
    9 => OP_LDX, 10 => x"F0", 11 => x"00",

    -- 12: MOSTRAR X EN DISPLAY 7 SEGMENTOS (Debug Visual)
    -- Si la CPU lee la tecla, verás el número aquí (Ej: A=10, 1=1, etc)
    12 => OP_DISP, 13 => x"00", 14 => x"00",

    -- 15: Comparar X con Y (que vale 0)
    15 => OP_CMP, 16 => x"00", 17 => x"00",

    -- 18: Si NO es cero (Tecla presionada), saltar a "CAMBIAR PANTALLA"
    18 => OP_BR_NZ, 19 => x"1B", 20 => x"00", -- Salta a dir 27 (x1B)

    -- 21: Si es cero, volver a Leer (Dir 9)
    21 => OP_JUMP, 22 => x"09", 23 => x"00",
    
    -- Padding para llenar hueco
    24 => x"00", 25 => x"00", 26 => x"00",

    -- ================= CAMBIAR PANTALLA =================
    -- 27: Si llegamos aquí, detectó tecla. Poner Barras de Colores (x20)
    27 => OP_LDI, 28 => x"20", 29 => x"00",
    30 => OP_STX, 31 => x"D0", 32 => x"00",

    -- 33: Quedarse aquí (Loop infinito mostrando Barras)
    33 => OP_JUMP, 34 => x"21", 35 => x"00", -- Salta a 33

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