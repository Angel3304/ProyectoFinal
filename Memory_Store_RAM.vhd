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
  constant OP_DISP  : std_logic_vector(7 downto 0) := x"06";
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
  constant OP_LDI   : std_logic_vector(7 downto 0) := x"12";  -- Nueva
  constant OP_LDIY  : std_logic_vector(7 downto 0) := x"13";  -- Nueva

  type t_mem_array is array (0 to 255) of std_logic_vector(7 downto 0);
  
  -- PROGRAMA PRINCIPAL DE RULETA (Como constante)
  constant mem_array : t_mem_array := (
    -- ============================================================
    -- INICIO: Inicialización
    -- ============================================================
    -- 0: Créditos Iniciales = 50 (x32)
    0 => OP_LDI, 1 => x"32", 2 => x"00",      
    3 => OP_STX, 4 => x"80", 5 => x"00",      -- Guardar en Créditos [x80]

    -- ============================================================
    -- ESTADO: MENU PRINCIPAL (Mostrar TU + Créditos)
    -- ============================================================
    -- 6: Manda comando visual x10 (Menú)
    6 => OP_LDI, 7 => x"10", 8 => x"00",      
    9 => OP_STX, 10 => x"D0", 11 => x"00",    -- Escribe en Video

    -- 12: POLLING TECLADO (Esperar tecla para elegir color)
    12 => OP_LDX, 13 => x"F0", 14 => x"00",   -- Lee Teclado
    15 => OP_CMP, 16 => x"00", 17 => x"00",   -- ¿Es 0?
    18 => OP_BR_NZ, 19 => x"18", 20 => x"00", -- Si NO es 0 (Tecla!), ir a procesar (Dir 24 hex = 18 hex ? No, 24 dec = 18 hex)
                                              -- CUIDADO: 24 decimal = x18 hexadecimal.
    21 => OP_JUMP, 22 => x"0C", 23 => x"00",  -- Si es 0, repetir (Ir a 12 decimal = x0C)

    -- ============================================================
    -- PROCESAR COLOR (Guardar selección)
    -- ============================================================
    -- Dir 24 (x18): Guardar tecla en [x81]
    24 => OP_STX, 25 => x"81", 26 => x"00",
    
    -- FEEDBACK VISUAL: Mostrar barras de colores (x20)
    27 => OP_LDI, 28 => x"20", 29 => x"00",
    30 => OP_STX, 31 => x"D0", 32 => x"00",
    
    -- (Aquí continuaría tu lógica de apuesta...)
    -- Por ahora, dejemos un bucle aquí para probar hasta este punto
    33 => OP_JUMP, 34 => x"21", 35 => x"00", -- Loop infinito en el estado de "Selección hecha"

    others => x"00"
  );

begin
  -- Lectura asíncrona de la constante
  Data_out <= mem_array(to_integer(unsigned(Addr_in))) & 
              mem_array(to_integer(unsigned(Addr_in)) + 1) & 
              mem_array(to_integer(unsigned(Addr_in)) + 2);
end architecture;